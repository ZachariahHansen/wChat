# lambda_function.py

import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
# DB_NAME = ''
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        # database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def test_db_connection(event, context):
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
        return response(200, {'message': 'Database connection successful'})
    except Exception as e:
        return response(500, {'error': f'Database connection failed: {str(e)}'})
    finally:
        if conn:
            conn.close()

def lambda_handler(event, context):
    # Handle preflight OPTIONS request
    if event['httpMethod'] == 'OPTIONS':
        return response(200, DB_HOST)
    
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

def get_user(event, cur):
    user_id = event['pathParameters']['id']
    cur.execute("""
        SELECT u.id, u.name, u.email, u.phone_number, u.role, d.name as department, s.schedule, array_agg(sh.shift_time) as shifts
        FROM users u
        LEFT JOIN departments d ON u.department_id = d.id
        LEFT JOIN schedules s ON u.id = s.user_id
        LEFT JOIN shifts sh ON u.id = sh.user_id
        WHERE u.id = %s
        GROUP BY u.id, d.name, s.schedule
    """, (user_id,))
    user = cur.fetchone()
    
    if user:
        return response(200, user)
    else:
        return response(404, {'error': 'User not found'})

def create_user(event, cur):
    user_data = json.loads(event['body'])
    required_fields = ['name', 'email', 'phone_number', 'role', 'department_id']
    
    if not all(field in user_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    cur.execute("""
        INSERT INTO users (name, email, phone_number, role, department_id)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id
    """, (user_data['name'], user_data['email'], user_data['phone_number'], user_data['role'], user_data['department_id']))
    
    new_user_id = cur.fetchone()['id']
    cur.connection.commit()
    
    return response(201, {'id': new_user_id})

def update_user(event, cur):
    user_id = event['pathParameters']['id']
    user_data = json.loads(event['body'])
    
    update_fields = []
    update_values = []
    
    for field in ['name', 'email', 'phone_number', 'role', 'department_id']:
        if field in user_data:
            update_fields.append(f"{field} = %s")
            update_values.append(user_data[field])
    
    if not update_fields:
        return response(400, {'error': 'No fields to update'})
    
    update_values.append(user_id)
    
    cur.execute(f"""
        UPDATE users
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

def delete_user(event, cur):
    user_id = event['pathParameters']['id']
    
    cur.execute("DELETE FROM users WHERE id = %s RETURNING id", (user_id,))
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
