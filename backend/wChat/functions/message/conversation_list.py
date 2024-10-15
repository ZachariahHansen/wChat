

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
            
            if event['httpMethod'] != 'GET':
                return response(405, {'error': 'Method not allowed'})
            
            return list_conversations(event, cur)
            
    finally:
        conn.close()


@authenticate
def list_conversations(event, cur):
    user_id = event['requestContext']['authorizer']['claims']['sub']
    
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
    """, (user_id,) * 8)
    
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
        'body': json.dumps(body)
    }