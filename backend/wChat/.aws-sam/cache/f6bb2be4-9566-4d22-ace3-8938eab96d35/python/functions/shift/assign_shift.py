import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate

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

@authenticate
def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    if event['httpMethod'] != 'PUT':
        return response(405, {'error': 'Method not allowed'})

    try:
        # Parse the request body
        body = json.loads(event['body'])
        shift_id = body.get('shift_id')
        user_id = body.get('user_id')
        
        if not shift_id or not user_id:
            return response(400, {'error': 'shift_id and user_id are required in the request body'})
        
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                return assign_user_to_shift(shift_id, user_id, cur)
        finally:
            conn.close()
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON in request body'})
    except Exception as e:
        return response(500, {'error': str(e)})

def assign_user_to_shift(shift_id, user_id, cur):
    # Check if the shift exists
    cur.execute("SELECT * FROM shift WHERE id = %s", (shift_id,))
    shift = cur.fetchone()
    if not shift:
        return response(404, {'error': 'Shift not found'})

    # Check if the user exists
    cur.execute("SELECT * FROM \"user\" WHERE id = %s", (user_id,))
    user = cur.fetchone()
    if not user:
        return response(404, {'error': 'User not found'})

    # Assign the user to the shift
    cur.execute("""
        UPDATE shift
        SET user_id = %s
        WHERE id = %s
        RETURNING id, user_id
    """, (user_id, shift_id))
    
    updated_shift = cur.fetchone()
    cur.connection.commit()
    
    if updated_shift:
        return response(200, {'message': 'User assigned to shift successfully', 'shift_id': updated_shift['id'], 'user_id': updated_shift['user_id']})
    else:
        return response(500, {'error': 'Failed to assign user to shift'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            "Access-Control-Allow-Methods": "OPTIONS,PUT"
        },
        'body': json.dumps(body)
    }