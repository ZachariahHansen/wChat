import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from functions.notifications.python.notification_service import NotificationService

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD
    )

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            if event['httpMethod'] == 'PUT':
                return update_user_role(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def update_user_role(event, cur):
    try:
        # Get user ID from path parameters
        user_id = event['pathParameters']['id']
        
        # Get role name from request body
        body = json.loads(event['body'])
        role_name = body.get('role_name')
        
        if not role_name:
            return response(400, {'error': 'Role name is required'})
        
        # First, verify that the role exists and get its ID
        cur.execute("""
            SELECT id, name FROM role WHERE name = %s
        """, (role_name,))
        
        role = cur.fetchone()
        if not role:
            return response(404, {'error': 'Role not found'})
        
        role_id = role['id']
        
        # Update the user's role
        cur.execute("""
            UPDATE "user"
            SET role_id = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING id, first_name, last_name, email, role_id
        """, (role_id, user_id))
        
        updated_user = cur.fetchone()
        
        if not updated_user:
            return response(404, {'error': 'User not found'})
        
        # Send notification to user about role change
        notification_service = NotificationService()
        notification_content = f"Your role has been updated to {role['name']}"
        notification_service.create_notification(user_id, notification_content)
        
        # Commit the transaction
        cur.connection.commit()
        
        return response(200, updated_user)
        
    except KeyError:
        return response(400, {'error': 'Missing required parameters'})
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON in request body'})
    except psycopg2.Error as e:
        # Log the database error (you might want to use proper logging)
        print(f"Database error: {e}")
        cur.connection.rollback()
        return response(500, {'error': 'Database error occurred'})
    except Exception as e:
        # Log the error (you might want to use proper logging)
        print(f"Unexpected error: {e}")
        cur.connection.rollback()
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'PATCH,OPTIONS'
        },
        'body': json.dumps(body)
    }
