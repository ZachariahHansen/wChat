import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from datetime import datetime, time

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

def datetime_handler(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    elif isinstance(obj, time):
        return obj.strftime('%H:%M')
    raise TypeError(f'Object of type {type(obj)} is not JSON serializable')

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')

    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            return get_all_users(event, cur)
    finally:
        conn.close()

@authenticate
def get_all_users(event, cur):
    # First get all users with their basic information
    cur.execute("""
        WITH user_departments AS (
            SELECT 
                dg.user_id,
                string_agg(d.name, ', ') as departments
            FROM department_group dg
            JOIN department d ON dg.department_id = d.id
            GROUP BY dg.user_id
        ),
        user_availability AS (
            SELECT 
                user_id,
                jsonb_agg(
                    jsonb_build_object(
                        'day', day,
                        'is_available', is_available,
                        'start_time', start_time,
                        'end_time', end_time
                    ) ORDER BY day
                ) as availability
            FROM availability
            GROUP BY user_id
        )
        SELECT 
            u.id,
            u.first_name,
            u.last_name,
            u.email,
            u.phone_number,
            u.hourly_rate,
            u.is_manager,
            u.created_at,
            u.updated_at,
            r.id as role_id,
            r.name as role_name,
            r.description as role_description,
            COALESCE(ud.departments, '') as departments,
            COALESCE(ua.availability, '[]'::jsonb) as availability
        FROM "user" u
        LEFT JOIN role r ON u.role_id = r.id
        LEFT JOIN user_departments ud ON u.id = ud.user_id
        LEFT JOIN user_availability ua ON u.id = ua.user_id
        ORDER BY u.last_name, u.first_name
    """)
    
    users = cur.fetchall()
    
    # Process availability to ensure all days are represented
    for user in users:
        availability_dict = {day: None for day in range(7)}
        current_availability = user['availability']
        
        # Convert from string to list if needed
        if isinstance(current_availability, str):
            current_availability = json.loads(current_availability)
            
        # Fill in the existing availability data
        for avail in current_availability:
            day = avail['day']
            availability_dict[day] = {
                'is_available': avail['is_available'],
                'start_time': avail['start_time'],
                'end_time': avail['end_time']
            }
            
        # Convert back to list format with all days
        user['availability'] = [
            {
                'day': day,
                'is_available': False if avail is None else avail['is_available'],
                'start_time': None if avail is None else avail['start_time'],
                'end_time': None if avail is None else avail['end_time']
            }
            for day, avail in availability_dict.items()
        ]
    
    return response(200, users)

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,OPTIONS'
        },
        'body': json.dumps(body, default=datetime_handler)
    }