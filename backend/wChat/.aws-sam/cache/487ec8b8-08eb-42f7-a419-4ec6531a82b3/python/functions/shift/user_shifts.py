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
                return get_user_shifts(event, cur)
            # ... other HTTP methods ...
    finally:
        conn.close()

@authenticate
def get_user_shifts(event, cur):
    user_id = event['pathParameters']['id']
    cur.execute("""
        SELECT s.id, s.start_time, s.end_time, s.status, 
               d.name as department_name
        FROM shift s
        LEFT JOIN department d ON s.department_id = d.id
        WHERE s.user_id = %s
        ORDER BY s.start_time
    """, (user_id,))
    shifts = cur.fetchall()
    
    return response(200, shifts)

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