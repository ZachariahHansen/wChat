import os
import json
import boto3
import psycopg2
from psycopg2.extras import RealDictCursor
from botocore.exceptions import ClientError

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']
DB_NAME = os.environ['DB_NAME']

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )

def lambda_handler(event, context):
    domain_name = event['requestContext']['domainName']
    stage = event['requestContext']['stage']
    api_client = boto3.client('apigatewaymanagementapi', endpoint_url=f'https://{domain_name}/{stage}')

    message_data = json.loads(event['body'])
    message_type = message_data['type']
    
    try:
        if message_type == 'direct_message':
            handle_direct_message(api_client, message_data)
        elif message_type == 'group_message':
            handle_group_message(api_client, message_data)
        elif message_type == 'broadcast':
            handle_broadcast(api_client, message_data)
        elif message_type == 'typing_indicator':
            handle_typing_indicator(api_client, message_data)
        elif message_type == 'read_receipt':
            handle_read_receipt(api_client, message_data)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'Invalid message type'})
            }
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Message processed successfully'})
        }
    
    except Exception as e:
        print(f"Error in broadcast: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Error in broadcast: {str(e)}'})
        }

def handle_direct_message(api_client, message_data):
    sender_id = message_data['sender_id']
    recipient_id = message_data['recipient_id']
    content = message_data['content']
    
    # Store the message in PostgreSQL
    message_id = store_message(sender_id, recipient_id, content, 'direct')
    
    # Send the message to the recipient
    send_message_to_user(api_client, recipient_id, {
        'type': 'direct_message',
        'message_id': message_id,
        'sender_id': sender_id,
        'content': content,
        'timestamp': message_data.get('timestamp', '')
    })

def handle_group_message(api_client, message_data):
    sender_id = message_data['sender_id']
    group_id = message_data['group_id']
    content = message_data['content']
    
    # Store the message in PostgreSQL
    message_id = store_message(sender_id, group_id, content, 'group')
    
    # Get all members of the group
    group_members = get_group_members(group_id)
    
    # Send the message to all group members except the sender
    for member_id in group_members:
        if member_id != sender_id:
            send_message_to_user(api_client, member_id, {
                'type': 'group_message',
                'message_id': message_id,
                'group_id': group_id,
                'sender_id': sender_id,
                'content': content,
                'timestamp': message_data.get('timestamp', '')
            })

def handle_broadcast(api_client, message_data):
    sender_id = message_data['sender_id']
    content = message_data['content']
    
    # Store the message in PostgreSQL
    message_id = store_message(sender_id, 'all', content, 'broadcast')
    
    # Send the message to all connected users
    broadcast_to_all(api_client, {
        'type': 'broadcast',
        'message_id': message_id,
        'sender_id': sender_id,
        'content': content,
        'timestamp': message_data.get('timestamp', '')
    })

def handle_typing_indicator(api_client, message_data):
    sender_id = message_data['sender_id']
    recipient_id = message_data['recipient_id']
    is_typing = message_data['is_typing']
    
    send_message_to_user(api_client, recipient_id, {
        'type': 'typing_indicator',
        'sender_id': sender_id,
        'is_typing': is_typing
    })

def handle_read_receipt(api_client, message_data):
    reader_id = message_data['reader_id']
    message_id = message_data['message_id']
    
    # Update the message as read in PostgreSQL
    update_message_read_status(message_id, reader_id)
    
    # Get the original sender of the message
    original_sender_id = get_message_sender(message_id)
    
    # Send read receipt to the original sender
    send_message_to_user(api_client, original_sender_id, {
        'type': 'read_receipt',
        'message_id': message_id,
        'reader_id': reader_id
    })

def store_message(sender_id, recipient_id, content, message_type):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO messages (sender_id, recipient_id, content, type, timestamp)
                VALUES (%s, %s, %s, %s, NOW())
                RETURNING id
            """, (sender_id, recipient_id, content, message_type))
            message_id = cur.fetchone()['id']
            conn.commit()
    return message_id

def broadcast_to_all(api_client, message):
    connections = get_all_connections()
    for connection in connections:
        send_message(api_client, connection['connection_id'], message)

def send_message_to_user(api_client, user_id, message):
    connections = get_connections_for_user(user_id)
    for connection in connections:
        send_message(api_client, connection['connection_id'], message)

def send_message(api_client, connection_id, message):
    try:
        api_client.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(message).encode('utf-8')
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'GoneException':
            remove_connection(connection_id)
        else:
            print(f"Error sending message to {connection_id}: {e}")

def get_all_connections():
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT connection_id FROM connections")
            return cur.fetchall()

def get_connections_for_user(user_id):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT connection_id FROM connections WHERE user_id = %s", (user_id,))
            return cur.fetchall()

def update_message_read_status(message_id, reader_id):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO message_reads (message_id, reader_id, read_at)
                VALUES (%s, %s, NOW())
                ON CONFLICT (message_id, reader_id) DO UPDATE
                SET read_at = NOW()
            """, (message_id, reader_id))
            conn.commit()

def get_message_sender(message_id):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT sender_id FROM messages WHERE id = %s", (message_id,))
            return cur.fetchone()['sender_id']

def remove_connection(connection_id):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM connections WHERE connection_id = %s", (connection_id,))
            conn.commit()