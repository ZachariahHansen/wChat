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

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            
            if http_method == 'GET':
                return get_availability(event, cur)
            elif http_method in ['POST', 'PUT']:  # Handle both POST and PUT the same way
                return upsert_availability(event, cur)
            elif http_method == 'DELETE':
                return delete_availability(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

def validate_availability_data(availability):
    """Validate a single day's availability data"""
    required_fields = ['day', 'start_time', 'end_time', 'is_available']
    if not all(field in availability for field in required_fields):
        return False, "Missing required fields"
    
    if not (0 <= availability['day'] <= 6):
        return False, "Day must be between 0 and 6"
    
    try:
        # Validate time format (HH:MM)
        for time_field in ['start_time', 'end_time']:
            time_str = availability[time_field]
            hours, minutes = map(int, time_str.split(':'))
            if not (0 <= hours < 24 and 0 <= minutes < 60):
                return False, f"Invalid time format in {time_field}"
                
        # Only check if end time is after start time when the day is available
        if availability['is_available']:
            start_hours, start_minutes = map(int, availability['start_time'].split(':'))
            end_hours, end_minutes = map(int, availability['end_time'].split(':'))
            
            start_minutes_total = start_hours * 60 + start_minutes
            end_minutes_total = end_hours * 60 + end_minutes
            
            if start_minutes_total >= end_minutes_total:
                return False, "End time must be after start time when day is available"
    except:
        return False, "Invalid time format"
    
    return True, ""

@authenticate
def upsert_availability(event, cur):
    """Create or update availability records"""
    try:
        user_id = event['pathParameters']['id']
        body = json.loads(event['body'])
        
        if 'availabilities' not in body:
            return response(400, {'error': 'Missing availabilities array'})
            
        availabilities = body['availabilities']
        if len(availabilities) != 7:
            return response(400, {'error': 'Must provide availability for all 7 days'})
        
        # Validate all availability records
        for availability in availabilities:
            is_valid, error_message = validate_availability_data(availability)
            if not is_valid:
                return response(400, {'error': error_message})
        
        # Delete existing availability records
        cur.execute("DELETE FROM availability WHERE user_id = %s", (user_id,))
        
        # Insert new availability records
        for availability in availabilities:
            cur.execute("""
                INSERT INTO availability (
                    user_id, 
                    day, 
                    is_available, 
                    start_time, 
                    end_time
                )
                VALUES (%s, %s, %s, %s::time, %s::time)
            """, (
                user_id,
                availability['day'],
                availability['is_available'],
                availability['start_time'],
                availability['end_time']
            ))
        
        cur.connection.commit()
        return response(201 if event['httpMethod'] == 'POST' else 200, 
                       {'message': 'Availability updated successfully'})
        
    except Exception as e:
        cur.connection.rollback()
        print(f"Error updating availability: {str(e)}")
        return response(500, {'error': 'Internal server error'})

@authenticate
def get_availability(event, cur):
    user_id = event['pathParameters']['id']
    
    cur.execute("""
        SELECT id, day, is_available, 
               to_char(start_time, 'HH24:MI') as start_time,
               to_char(end_time, 'HH24:MI') as end_time
        FROM availability
        WHERE user_id = %s
        ORDER BY day
    """, (user_id,))
    
    availabilities = cur.fetchall()
    return response(200, {'availabilities': availabilities})

@authenticate
def delete_availability(event, cur):
    try:
        user_id = event['pathParameters']['id']
        
        cur.execute("DELETE FROM availability WHERE user_id = %s RETURNING id", (user_id,))
        deleted_rows = cur.fetchall()
        
        if not deleted_rows:
            return response(404, {'error': 'No availability records found'})
            
        cur.connection.commit()
        return response(200, {'message': 'Availability deleted successfully'})
        
    except Exception as e:
        cur.connection.rollback()
        print(f"Error deleting availability: {str(e)}")
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,PUT,DELETE'
        },
        'body': json.dumps(body)
    }