import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor

# Database connection parameters
DB_HOST = os.environ['DB_HOST']

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
    # Handle preflight OPTIONS request
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')

    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            
            if http_method == 'GET':
                return get_shift(event, cur)
            elif http_method == 'POST':
                return create_shift(event, cur)
            elif http_method == 'PUT':
                return update_shift(event, cur)
            elif http_method == 'DELETE':
                return delete_shift(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

def get_shift(event, cur):
    shift_id = event['pathParameters']['id']
    cur.execute("""
        SELECT s.id, s.start_time, s.end_time, s.status, d.name as department, u.name as scheduled_by
        FROM shift s
        LEFT JOIN departments d ON s.department_id = d.id
        LEFT JOIN users u ON s.scheduled_by = u.id
        WHERE s.id = %s
    """, (shift_id,))
    shift = cur.fetchone()
    
    if shift:
        return response(200, shift)
    else:
        return response(404, {'error': 'Shift not found'})

def create_shift(event, cur):
    shift_data = json.loads(event['body'])
    required_fields = ['start_time', 'end_time', 'status', 'department_id', 'scheduled_by']
    
    if not all(field in shift_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    cur.execute("""
        INSERT INTO shift (start_time, end_time, status, department_id, scheduled_by)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id
    """, (shift_data['start_time'], shift_data['end_time'], shift_data['status'], 
          shift_data['department_id'], shift_data['scheduled_by']))
    
    new_shift_id = cur.fetchone()['id']
    cur.connection.commit()
    
    return response(201, {'id': new_shift_id})

def update_shift(event, cur):
    shift_id = event['pathParameters']['id']
    shift_data = json.loads(event['body'])
    
    update_fields = []
    update_values = []
    
    for field in ['start_time', 'end_time', 'status', 'department_id', 'scheduled_by']:
        if field in shift_data:
            update_fields.append(f"{field} = %s")
            update_values.append(shift_data[field])
    
    if not update_fields:
        return response(400, {'error': 'No fields to update'})
    
    update_values.append(shift_id)
    
    cur.execute(f"""
        UPDATE shift
        SET {', '.join(update_fields)}
        WHERE id = %s
        RETURNING id
    """, tuple(update_values))
    
    updated_shift = cur.fetchone()
    cur.connection.commit()
    
    if updated_shift:
        return response(200, {'message': 'Shift updated successfully'})
    else:
        return response(404, {'error': 'Shift not found'})

def delete_shift(event, cur):
    shift_id = event['pathParameters']['id']
    
    cur.execute("DELETE FROM shift WHERE id = %s RETURNING id", (shift_id,))
    deleted_shift = cur.fetchone()
    cur.connection.commit()
    
    if deleted_shift:
        return response(200, {'message': 'Shift deleted successfully'})
    else:
        return response(404, {'error': 'Shift not found'})

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