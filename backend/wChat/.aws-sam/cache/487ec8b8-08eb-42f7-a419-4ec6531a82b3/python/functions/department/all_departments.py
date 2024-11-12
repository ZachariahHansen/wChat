import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from datetime import datetime

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
    raise TypeError(f'Object of type {type(obj)} is not JSON serializable')

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')

    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            return get_all_departments(event, cur)
    finally:
        conn.close()

@authenticate
def get_all_departments(event, cur):
    cur.execute("""
        WITH department_stats AS (
            SELECT 
                d.id as dept_id,
                COUNT(DISTINCT dg.user_id) as member_count,
                COUNT(DISTINCT s.id) as shift_count
            FROM department d
            LEFT JOIN department_group dg ON d.id = dg.department_id
            LEFT JOIN shift s ON d.id = s.department_id
            GROUP BY d.id
        )
        SELECT 
            d.id,
            d.name,
            d.description,
            COALESCE(ds.member_count, 0) as member_count,
            COALESCE(ds.shift_count, 0) as shift_count,
            STRING_AGG(DISTINCT CONCAT(u.first_name, ' ', u.last_name), ', ') as managers
        FROM department d
        LEFT JOIN department_stats ds ON d.id = ds.dept_id
        LEFT JOIN department_group dg ON d.id = dg.department_id
        LEFT JOIN "user" u ON dg.user_id = u.id AND u.is_manager = true
        GROUP BY 
            d.id,
            d.name,
            d.description,
            ds.member_count,
            ds.shift_count
        ORDER BY d.name
    """)
    departments = cur.fetchall()
    
    return response(200, departments)

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