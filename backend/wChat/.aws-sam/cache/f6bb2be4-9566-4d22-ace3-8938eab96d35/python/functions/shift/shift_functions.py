import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from datetime import datetime, date

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

# Custom JSON encoder to handle datetime objects
class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        return super(DateTimeEncoder, self).default(obj)

def lambda_handler(event, context):
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

@authenticate
def get_shift(event, cur):
    shift_id = event['pathParameters']['id']
    cur.execute("""
        SELECT s.id, s.start_time, s.end_time, s.status, 
               s.scheduled_by_id, u.first_name || ' ' || u.last_name AS scheduled_by_name,
               s.department_id, d.name AS department_name,
               s.user_id, u2.first_name || ' ' || u2.last_name AS assigned_user_name
        FROM shift s
        LEFT JOIN "user" u ON s.scheduled_by_id = u.id
        LEFT JOIN department d ON s.department_id = d.id
        LEFT JOIN "user" u2 ON s.user_id = u2.id
        WHERE s.id = %s
    """, (shift_id,))
    shift = cur.fetchone()
    
    if shift:
        return response(200, shift)
    else:
        return response(404, {'error': 'Shift not found'})

@authenticate
@authenticate
def create_shift(event, cur):
    shift_data = json.loads(event['body'])
    required_fields = ['start_time', 'end_time', 'scheduled_by_id', 'department_id']
    
    if not all(field in shift_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    # Convert string dates to datetime objects
    start_time = datetime.fromisoformat(shift_data['start_time'])
    end_time = datetime.fromisoformat(shift_data['end_time'])
    
    cur.execute("""
        INSERT INTO shift (start_time, end_time, scheduled_by_id, department_id, user_id, status)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id
    """, (start_time, end_time, shift_data['scheduled_by_id'], 
          shift_data['department_id'], shift_data.get('user_id'), shift_data.get('status', 'scheduled')))
    
    new_shift_id = cur.fetchone()['id']
    cur.connection.commit()
    
    return response(201, {'id': new_shift_id})

@authenticate
def update_shift(event, cur):
    shift_id = event['pathParameters']['id']
    shift_data = json.loads(event['body'])
    
    update_fields = []
    update_values = []
    
    for field in ['start_time', 'end_time', 'scheduled_by_id', 'department_id', 'user_id', 'status']:
        if field in shift_data:
            if field in ['start_time', 'end_time']:
                shift_data[field] = datetime.fromisoformat(shift_data[field])
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

@authenticate
def delete_shift(event, cur):
    shift_id = event['pathParameters']['id']
    
    cur.execute('DELETE FROM shift WHERE id = %s RETURNING id', (shift_id,))
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
        'body': json.dumps(body, cls=DateTimeEncoder)
    }