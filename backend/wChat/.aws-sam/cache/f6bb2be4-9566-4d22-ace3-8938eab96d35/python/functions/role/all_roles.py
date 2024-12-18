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
            return get_all_roles(event, cur)
    finally:
        conn.close()

@authenticate
def get_all_roles(event, cur):
    cur.execute("""
        WITH role_users AS (
            SELECT 
                r.id as role_id,
                COUNT(u.id) as user_count
            FROM role r
            LEFT JOIN "user" u ON r.id = u.role_id
            GROUP BY r.id
        )
        SELECT 
            r.id,
            r.name,
            r.description,
            COALESCE(ru.user_count, 0) as user_count
        FROM role r
        LEFT JOIN role_users ru ON r.id = ru.role_id
        ORDER BY r.name
    """)
    roles = cur.fetchall()
    
    return response(200, roles)

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