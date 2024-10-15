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
            path = event['path']
            
            if path.endswith('/conversations'):
                return list_conversations(event, cur)
            elif '/messages/' in path:
                if http_method == 'GET':
                    return get_messages(event, cur)
                elif http_method == 'POST':
                    return send_message(event, cur)
                elif http_method == 'PUT':
                    return update_message(event, cur)
                elif http_method == 'DELETE':
                    return delete_message(event, cur)
            else:
                return response(404, {'error': 'Not found'})
    finally:
        conn.close()

@authenticate
def get_messages(event, cur):
    user_id = event['requestContext']['authorizer']['claims']['sub']
    other_user_id = event['pathParameters']['id']
    
    cur.execute("""
        SELECT m.*, 
            u_sender.first_name AS sender_first_name, 
            u_sender.last_name AS sender_last_name,
            u_receiver.first_name AS receiver_first_name, 
            u_receiver.last_name AS receiver_last_name
        FROM message m
        JOIN "user" u_sender ON m.sent_by_user_id = u_sender.id
        JOIN "user" u_receiver ON m.received_by_user_id = u_receiver.id
        WHERE (m.sent_by_user_id = %s AND m.received_by_user_id = %s)
        OR (m.sent_by_user_id = %s AND m.received_by_user_id = %s)
        ORDER BY m.time_stamp ASC
    """, (user_id, other_user_id, other_user_id, user_id))
    
    messages = cur.fetchall()
    return response(200, messages)

@authenticate
def send_message(event, cur):
    user_id = event['requestContext']['authorizer']['claims']['sub']
    message_data = json.loads(event['body'])
    
    required_fields = ['content', 'received_by_user_id']
    if not all(field in message_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    cur.execute("""
        INSERT INTO message (content, time_stamp, sent_by_user_id, received_by_user_id)
        VALUES (%s, CURRENT_TIMESTAMP, %s, %s)
        RETURNING id
    """, (message_data['content'], user_id, message_data['received_by_user_id']))
    
    new_message_id = cur.fetchone()['id']
    cur.connection.commit()
    
    return response(201, {'id': new_message_id})

@authenticate
def update_message(event, cur):
    user_id = event['requestContext']['authorizer']['claims']['sub']
    message_id = event['pathParameters']['id']
    message_data = json.loads(event['body'])
    
    if 'content' not in message_data:
        return response(400, {'error': 'Missing content field'})
    
    cur.execute("""
        UPDATE message
        SET content = %s, time_stamp = CURRENT_TIMESTAMP
        WHERE id = %s AND sent_by_user_id = %s
        RETURNING id
    """, (message_data['content'], message_id, user_id))
    
    updated_message = cur.fetchone()
    cur.connection.commit()
    
    if updated_message:
        return response(200, {'message': 'Message updated successfully'})
    else:
        return response(404, {'error': 'Message not found or you are not authorized to update it'})

@authenticate
def delete_message(event, cur):
    user_id = event['requestContext']['authorizer']['claims']['sub']
    message_id = event['pathParameters']['id']
    
    cur.execute("""
        DELETE FROM message
        WHERE id = %s AND sent_by_user_id = %s
        RETURNING id
    """, (message_id, user_id))
    
    deleted_message = cur.fetchone()
    cur.connection.commit()
    
    if deleted_message:
        return response(200, {'message': 'Message deleted successfully'})
    else:
        return response(404, {'error': 'Message not found or you are not authorized to delete it'})

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