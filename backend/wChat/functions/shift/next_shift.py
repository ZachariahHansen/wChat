import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, date
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

# Custom JSON encoder to handle datetime objects
class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        return super(DateTimeEncoder, self).default(obj)

@authenticate
def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            if event['httpMethod'] == 'GET':
                return get_next_shift(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

def get_next_shift(event, cur):
    user_id = event['pathParameters']['id']
    current_time = datetime.now().isoformat()

    cur.execute("""
        SELECT s.id, s.start_time, s.end_time, s.status, d.name as department_name
        FROM shift s
        JOIN department d ON s.department_id = d.id
        WHERE s.user_id = %s AND s.start_time > %s
        ORDER BY s.start_time ASC
        LIMIT 1
    """, (user_id, current_time))
    
    next_shift = cur.fetchone()
    
    if next_shift:
        return response(200, next_shift)
    else:
        return response(404, {'error': 'No upcoming shifts found for this user'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,GET'
        },
        'body': json.dumps(body, cls=DateTimeEncoder)  # Use the custom encoder here
    }