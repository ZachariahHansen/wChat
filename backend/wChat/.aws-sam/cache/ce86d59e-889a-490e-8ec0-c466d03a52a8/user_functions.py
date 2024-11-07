import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
import bcrypt
from functions.auth_layer.auth import authenticate
import boto3
import jwt

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
# DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']
JWT_SECRET = os.environ['JWT_SECRET']

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        # database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            path = event['path']    

            # Handle the /users/register endpoint separately
            if path.endswith('/users/register') and http_method == 'POST':
                return create_user(event, cur)
            
            if http_method == 'GET':
                return get_user(event, cur)
            elif http_method == 'POST':
                return create_user(event, cur)
            elif http_method == 'PUT':
                return update_user(event, cur)
            elif http_method == 'DELETE':
                return delete_user(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def get_user(event, cur):
    user_id = event['pathParameters']['id']
    cur.execute("""
        SELECT u.id, u.first_name, u.last_name, u.email, u.phone_number, u.hourly_rate, u.is_manager, 
               r.name as role, d.name as department
        FROM "user" u
        LEFT JOIN role r ON u.role_id = r.id
        LEFT JOIN department_group dg ON u.id = dg.user_id
        LEFT JOIN department d ON dg.department_id = d.id
        WHERE u.id = %s
    """, (user_id,))
    user = cur.fetchone()
    
    if user:
        return response(200, user)
    else:
        return response(404, {'error': 'User not found'})

def create_user(event, cur):
    user_data = json.loads(event['body'])
    required_fields = ['first_name', 'last_name', 'email', 'phone_number', 'hourly_rate', 'role_id', 'password', 'is_manager']
    
    if not all(field in user_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    # Store plain password for email
    temp_password = user_data['password']
    password_hash = bcrypt.hashpw(temp_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    #check if the role exists
    cur.execute("SELECT * FROM role WHERE id = %s", (user_data['role_id'],))
    role = cur.fetchone()
    if not role:
        return response(404, {'error': 'Role not found'})
    
    cur.execute("""
    INSERT INTO "user" (first_name, last_name, email, phone_number, hourly_rate, role_id, is_manager, password)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    RETURNING id, first_name, last_name, email
""", (user_data['first_name'], user_data['last_name'], user_data['email'], user_data['phone_number'], 
      user_data['hourly_rate'], user_data['role_id'], user_data['is_manager'], password_hash))
    
    new_user = cur.fetchone()
    cur.connection.commit()

    # Send welcome email with temporary password
    try:
        lambda_client = boto3.client('lambda')
        email_payload = {
            'httpMethod': 'POST',
            'body': json.dumps({
                'template_type': 'new_user',
                'recipient_id': new_user['id'],
                'template_data': {
                    'user_name': f"{new_user['first_name']} {new_user['last_name']}",
                    'temp_password': temp_password
                }
            })
        }
        
        lambda_client.invoke(
            FunctionName=os.environ['EMAIL_FUNCTION_NAME'],
            InvocationType='Event',
            Payload=json.dumps(email_payload)
        )
    except Exception as e:
        print(f"Error sending welcome email: {str(e)}")
        # Continue with user creation even if email fails
    
    return response(201, {'id': new_user['id']})

@authenticate
def update_user(event, cur):
    try:
        # Get user ID from path parameters and convert to int
        user_id = int(event['pathParameters']['id'])
        
        # Get and validate JWT token
        auth_header = event.get('headers', {}).get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return response(401, {'error': 'Invalid authorization header'})
        
        token = auth_header.split(' ')[1]
        try:
            # Decode and verify JWT token
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            token_user_id = payload.get('user_id')
            
            # Verify that the token user_id matches the requested user_id
            if token_user_id != user_id:
                return response(403, {'error': 'Not authorized to update this user\'s information'})
                
        except jwt.ExpiredSignatureError:
            return response(401, {'error': 'Token has expired'})
        except jwt.InvalidTokenError:
            return response(401, {'error': 'Invalid token'})
        
        # Parse request body
        user_data = json.loads(event['body'])
        
        update_fields = []
        update_values = []
        
        # Define allowed fields and their validation rules
        allowed_fields = {
            'first_name': str,
            'last_name': str,
            'email': str,
            'phone_number': str,
            'hourly_rate': (float, int),
            'role_id': int,
            'is_manager': bool
        }
        
        # Validate and process each field
        for field, expected_type in allowed_fields.items():
            if field in user_data:
                value = user_data[field]
                
                # Check if value is of expected type
                if not isinstance(value, expected_type):
                    if expected_type == (float, int) and isinstance(value, (float, int)):
                        # Special case for hourly_rate which can be float or int
                        pass
                    else:
                        return response(400, {'error': f'Invalid type for field {field}'})
                
                update_fields.append(f"{field} = %s")
                update_values.append(value)
        
        if not update_fields:
            return response(400, {'error': 'No fields to update'})
        
        # Add updated_at timestamp
        update_fields.append("updated_at = CURRENT_TIMESTAMP")
        
        # Add WHERE clause parameter
        update_values.append(user_id)
        
        # Execute update query
        cur.execute(f"""
            UPDATE "user"
            SET {', '.join(update_fields)}
            WHERE id = %s
            RETURNING id
        """, tuple(update_values))
        
        updated_user = cur.fetchone()
        cur.connection.commit()
        
        if updated_user:
            return response(200, {'message': 'User updated successfully'})
        else:
            return response(404, {'error': 'User not found'})
            
    except ValueError as e:
        return response(400, {'error': f'Invalid input: {str(e)}'})
    except Exception as e:
        print(f"Error updating user: {str(e)}")
        return response(500, {'error': 'Internal server error'})

@authenticate
def delete_user(event, cur):
    user_id = event['pathParameters']['id']
    
    cur.execute('DELETE FROM "user" WHERE id = %s RETURNING id', (user_id,))
    deleted_user = cur.fetchone()
    cur.connection.commit()
    
    if deleted_user:
        return response(200, {'message': 'User deleted successfully'})
    else:
        return response(404, {'error': 'User not found'})

def     response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET,PUT,DELETE"
        },
        'body': json.dumps(body)
    }
