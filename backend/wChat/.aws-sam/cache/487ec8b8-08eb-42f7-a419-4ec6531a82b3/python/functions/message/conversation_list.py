import json
import os
import jwt
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from datetime import datetime

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
            
            if event['httpMethod'] != 'GET':
                return response(405, {'error': 'Method not allowed'})
            
            return list_conversations(event, cur)
            
    finally:
        conn.close()


@authenticate
def list_conversations(event, cur):
    user_id = get_user_id_from_token(event)
    
    cur.execute("""
        SELECT DISTINCT
            CASE 
                WHEN m.sent_by_user_id = %s THEN m.received_by_user_id
                ELSE m.sent_by_user_id
            END AS other_user_id,
            u.first_name,
            u.last_name,
            m2.content AS last_message,
            m2.time_stamp AS last_message_time
        FROM message m
        JOIN "user" u ON 
            CASE 
                WHEN m.sent_by_user_id = %s THEN u.id = m.received_by_user_id
                ELSE u.id = m.sent_by_user_id
            END
        JOIN (
            SELECT 
                CASE 
                    WHEN sent_by_user_id = %s THEN received_by_user_id
                    ELSE sent_by_user_id
                END AS other_user_id,
                content,
                time_stamp,
                ROW_NUMBER() OVER (
                    PARTITION BY 
                        CASE 
                            WHEN sent_by_user_id = %s THEN received_by_user_id
                            ELSE sent_by_user_id
                        END
                    ORDER BY time_stamp DESC
                ) AS rn
            FROM message
            WHERE sent_by_user_id = %s OR received_by_user_id = %s
        ) m2 ON m2.other_user_id = 
            CASE 
                WHEN m.sent_by_user_id = %s THEN m.received_by_user_id
                ELSE m.sent_by_user_id
            END
        WHERE (m.sent_by_user_id = %s OR m.received_by_user_id = %s)
        AND m2.rn = 1
        ORDER BY m2.time_stamp DESC
    """, (user_id,) * 9)
    
    conversations = cur.fetchall()
    return response(200, conversations)

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET,PUT,DELETE"
        },
        'body': json.dumps(body, default=datetime_handler)
    }