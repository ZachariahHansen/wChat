import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
import bcrypt
from functions.auth_layer.auth import authenticate

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
# DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']

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
    
    password_hash = bcrypt.hashpw(user_data['password'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    #check if the role exists
    cur.execute("SELECT * FROM role WHERE id = %s", (user_data['role_id'],))
    role = cur.fetchone()
    if not role:
        return response(404, {'error': 'Role not found'})
    
    cur.execute("""
    INSERT INTO "user" (first_name, last_name, email, phone_number, hourly_rate, role_id, is_manager, password)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    RETURNING id
""", (user_data['first_name'], user_data['last_name'], user_data['email'], user_data['phone_number'], 
      user_data['hourly_rate'], user_data['role_id'], user_data['is_manager'], password_hash))
    
    new_user_id = cur.fetchone()['id']
    cur.connection.commit()
    
    return response(201, {'id': new_user_id})

@authenticate
def update_user(event, cur):
    user_id = event['pathParameters']['id']
    user_data = json.loads(event['body'])
    
    update_fields = []
    update_values = []
    
    for field in ['first_name', 'last_name', 'email', 'phone_number', 'hourly_rate', 'role_id', 'is_manager']:
        if field in user_data:
            update_fields.append(f"{field} = %s")
            update_values.append(user_data[field])
    
    if not update_fields:
        return response(400, {'error': 'No fields to update'})
    
    update_fields.append("updated_at = CURRENT_TIMESTAMP")
    update_values.append(user_id)
    
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

def response(status_code, body):
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