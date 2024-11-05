import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
import bcrypt
import jwt
from functions.auth_layer.auth import authenticate

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']
JWT_SECRET = os.environ['JWT_SECRET']

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD
    )

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    if event['httpMethod'] != 'PUT':
        return response(405, {'error': 'Method not allowed'})
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            return update_password(event, cur)
    finally:
        conn.close()

@authenticate
def update_password(event, cur):
    try:
        # Get user ID from path parameters
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
                return response(403, {'error': 'Not authorized to update this user\'s password'})
                
        except jwt.ExpiredSignatureError:
            return response(401, {'error': 'Token has expired'})
        except jwt.InvalidTokenError:
            return response(401, {'error': 'Invalid token'})
        
        # Parse request body
        body = json.loads(event['body'])
        current_password = body.get('current_password')
        new_password = body.get('new_password')
        
        if not current_password or not new_password:
            return response(400, {'error': 'Current password and new password are required'})
            
        # Validate new password
        if len(new_password) < 8:
            return response(400, {'error': 'New password must be at least 8 characters long'})
        
        # Get current password hash from database
        cur.execute(
            'SELECT password FROM "user" WHERE id = %s',
            (user_id,)
        )
        
        user = cur.fetchone()
        if not user:
            return response(404, {'error': 'User not found'})
            
        # Verify current password
        if not bcrypt.checkpw(current_password.encode('utf-8'), user['password'].encode('utf-8')):
            return response(401, {'error': 'Current password is incorrect'})
            
        # Hash new password
        new_password_hash = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        
        # Update password in database
        cur.execute("""
            UPDATE "user"
            SET password = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING id
        """, (new_password_hash, user_id))
        
        updated_user = cur.fetchone()
        if not updated_user:
            return response(404, {'error': 'User not found'})
            
        cur.connection.commit()
        return response(200, {'message': 'Password updated successfully'})
        
    except ValueError as e:
        return response(400, {'error': str(e)})
    except Exception as e:
        print(f"Error updating password: {str(e)}")
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,PUT'
        },
        'body': json.dumps(body)
    }