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
                return get_available_department_shifts(event, cur)
    finally:
        conn.close()

def get_available_department_shifts(event, cur):
    department_id = event['pathParameters']['id']
    cur.execute("""
        SELECT s.id, s.start_time, s.end_time, s.status, u.name as scheduled_by
        FROM shift s
        LEFT JOIN users u ON s.scheduled_by = u.id
        WHERE s.department_id = %s
    """, (department_id))
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
        'body': json.dumps(body)
    }