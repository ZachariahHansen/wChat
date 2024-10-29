import json
import os
import jwt
import psycopg2
from psycopg2.extras import RealDictCursor
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

def get_user_id_from_token(event):
    try:
        # Extract the JWT token from the Authorization header
        auth_header = event['headers'].get('Authorization')
        if not auth_header:
            raise Exception('No Authorization header found')
        
        # Remove 'Bearer ' prefix if present
        token = auth_header.replace('Bearer ', '')
        
        # Decode the JWT token
        decoded_token = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        
        # Return the user ID from the token
        user_id = decoded_token.get('user_id')
        if user_id is None:
            raise Exception('No user_id found in token')
            
        return user_id
    except Exception as e:
        print(f"Error extracting user ID from token: {str(e)}")
        raise Exception('Invalid or expired token')

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            
            if http_method == 'GET':
                return get_available_shifts(event, cur)
            elif http_method == 'POST':
                path = event['path']
                if path.endswith('/relinquish'):
                    return relinquish_shift(event, cur)
                elif path.endswith('/pickup'):
                    return pickup_shift(event, cur)
                else:
                    return response(400, {'error': 'Invalid endpoint'})
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def get_available_shifts(event, cur):
    user_id = get_user_id_from_token(event)
    
    # Get user's department(s)
    cur.execute("""
        SELECT department_id 
        FROM department_group 
        WHERE user_id = %s
    """, (user_id,))
    
    user_departments = [row['department_id'] for row in cur.fetchall()]
    
    if not user_departments:
        return response(400, {'error': 'User not assigned to any departments'})
    
    # Get available shifts for user's departments
    cur.execute("""
        SELECT 
            s.id,
            s.start_time,
            s.end_time,
            s.status,
            d.name as department_name,
            CASE 
                WHEN s.user_id IS NOT NULL THEN json_build_object(
                    'id', u.id,
                    'first_name', u.first_name,
                    'last_name', u.last_name
                )
                ELSE NULL 
            END as current_user
        FROM shift s
        JOIN department d ON s.department_id = d.id
        LEFT JOIN "user" u ON s.user_id = u.id
        WHERE (s.status = 'available_for_exchange' OR s.user_id IS NULL)
        AND s.department_id = ANY(%s)
        AND s.start_time > CURRENT_TIMESTAMP
        AND s.status != 'completed'
        AND s.status != 'cancelled'
        ORDER BY s.start_time ASC
    """, (user_departments,))
    
    available_shifts = cur.fetchall()
    
    # Convert datetime objects to strings for JSON serialization
    for shift in available_shifts:
        shift['start_time'] = shift['start_time'].isoformat()
        shift['end_time'] = shift['end_time'].isoformat()
    
    return response(200, {
        'shifts': available_shifts,
        'total': len(available_shifts)
    })

@authenticate
def relinquish_shift(event, cur):
    data = json.loads(event['body'])
    
    if 'shift_id' not in data:
        return response(400, {'error': 'Missing shift_id'})
    
    shift_id = data['shift_id']
    user_id = get_user_id_from_token(event)
    
    # Check if the shift belongs to the user and is in a valid state
    cur.execute("""
        SELECT id, status 
        FROM shift 
        WHERE id = %s AND user_id = %s
    """, (shift_id, user_id))
    
    shift = cur.fetchone()
    if not shift:
        return response(404, {'error': 'Shift not found or does not belong to user'})
    
    if shift['status'] != 'scheduled':
        return response(400, {'error': 'Shift cannot be relinquished - invalid status'})
    
    # Update shift status to available_for_exchange
    cur.execute("""
        UPDATE shift 
        SET status = 'available_for_exchange'
        WHERE id = %s AND user_id = %s
        RETURNING id
    """, (shift_id, user_id))
    
    if cur.fetchone():
        cur.connection.commit()
        return response(200, {'message': 'Shift successfully marked as available for exchange'})
    else:
        return response(400, {'error': 'Failed to update shift status'})

@authenticate
def pickup_shift(event, cur):
    data = json.loads(event['body'])
    
    if 'shift_id' not in data:
        return response(400, {'error': 'Missing shift_id'})
    
    shift_id = data['shift_id']
    user_id = get_user_id_from_token(event)
    
    # Check if shift is available for pickup
    cur.execute("""
        SELECT id, department_id, start_time, end_time, user_id as current_user_id
        FROM shift 
        WHERE id = %s AND status = 'available_for_exchange'
    """, (shift_id,))
    
    shift = cur.fetchone()
    if not shift:
        return response(404, {'error': 'Shift not available for pickup'})
    
    # Prevent user from picking up their own shift
    if shift['current_user_id'] == user_id:
        return response(400, {'error': 'Cannot pick up your own shift'})
    
    # Check if user is in the correct department
    cur.execute("""
        SELECT 1 
        FROM department_group 
        WHERE user_id = %s AND department_id = %s
    """, (user_id, shift['department_id']))
    
    if not cur.fetchone():
        return response(403, {'error': 'User not authorized for this department'})
    
    # Check for schedule conflicts
    cur.execute("""
        SELECT 1 
        FROM shift 
        WHERE user_id = %s 
        AND status IN ('scheduled', 'available_for_exchange')
        AND (
            (start_time <= %s AND end_time >= %s)
            OR (start_time <= %s AND end_time >= %s)
            OR (start_time >= %s AND end_time <= %s)
        )
    """, (user_id, shift['start_time'], shift['start_time'], 
          shift['end_time'], shift['end_time'], 
          shift['start_time'], shift['end_time']))
    
    if cur.fetchone():
        return response(409, {'error': 'Schedule conflict detected'})
    
    # Update shift assignment and status
    cur.execute("""
        UPDATE shift 
        SET user_id = %s,
            status = 'scheduled'
        WHERE id = %s AND status = 'available_for_exchange'
        RETURNING id
    """, (user_id, shift_id))
    
    if cur.fetchone():
        cur.connection.commit()
        return response(200, {'message': 'Shift successfully picked up'})
    else:
        return response(400, {'error': 'Failed to pick up shift'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,POST'
        },
        'body': json.dumps(body)
    }