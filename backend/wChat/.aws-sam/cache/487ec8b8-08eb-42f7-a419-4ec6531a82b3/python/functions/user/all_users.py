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
            return get_all_users(event, cur)
    finally:
        conn.close()

@authenticate
def get_all_users(event, cur):
    cur.execute("""
        WITH user_departments AS (
            SELECT 
                dg.user_id,
                string_agg(d.name, ', ') as departments
            FROM department_group dg
            JOIN department d ON dg.department_id = d.id
            GROUP BY dg.user_id
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
            COALESCE(ud.departments, '') as departments
        FROM "user" u
        LEFT JOIN role r ON u.role_id = r.id
        LEFT JOIN user_departments ud ON u.id = ud.user_id
        ORDER BY u.last_name, u.first_name
    """)
    users = cur.fetchall()
    
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