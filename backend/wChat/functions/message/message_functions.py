import json
import os
import boto3
import psycopg2
import jwt
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate

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

def get_websocket_endpoint():
    return f"https://{os.environ.get('WEBSOCKET_API_DOMAIN')}/{os.environ.get('WEBSOCKET_API_STAGE')}"

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            
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
    user_id = get_user_id_from_token(event)
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
    user_id = get_user_id_from_token(event)
    message_data = json.loads(event['body'])
    
    required_fields = ['content', 'received_by_user_id']
    if not all(field in message_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    try:
        # Insert the new message
        cur.execute("""
            INSERT INTO message (content, time_stamp, sent_by_user_id, received_by_user_id)
            VALUES (%s, CURRENT_TIMESTAMP, %s, %s)
            RETURNING id, time_stamp
        """, (message_data['content'], user_id, message_data['received_by_user_id']))
        
        new_message = cur.fetchone()
        
        # Get sender details
        cur.execute("""
            SELECT first_name, last_name
            FROM "user"
            WHERE id = %s
        """, (user_id,))
        sender = cur.fetchone()
        
        # Prepare WebSocket message payload
        websocket_message = {
            'type': 'new_message',
            'message': {
                'id': new_message['id'],
                'content': message_data['content'],
                'time_stamp': new_message['time_stamp'].isoformat(),
                'sent_by_user_id': user_id,
                'sender_first_name': sender['first_name'],
                'sender_last_name': sender['last_name'],
                'received_by_user_id': message_data['received_by_user_id']
            }
        }
        
        # Send WebSocket message
        send_websocket_message(message_data['received_by_user_id'], websocket_message)
        
        # Commit the transaction
        cur.connection.commit()
        
        return response(201, {'id': new_message['id']})
    
    except Exception as e:
        cur.connection.rollback()
        print(f"Error in send_message: {str(e)}")
        return response(500, {'error': 'An error occurred while sending the message'})

@authenticate
def update_message(event, cur):
    user_id = event['requestContext']['authorizer']['claims']['sub']
    message_id = event['pathParameters']['id']
    message_data = json.loads(event['body'])
    
    if 'content' not in message_data:
        return response(400, {'error': 'Missing content field'})
    
    try:
        # Update the message
        cur.execute("""
            UPDATE message
            SET content = %s, time_stamp = CURRENT_TIMESTAMP
            WHERE id = %s AND sent_by_user_id = %s
            RETURNING id, received_by_user_id, time_stamp
        """, (message_data['content'], message_id, user_id))
        
        updated_message = cur.fetchone()
        
        if updated_message:
            # Get sender details
            cur.execute("""
                SELECT first_name, last_name
                FROM "user"
                WHERE id = %s
            """, (user_id,))
            sender = cur.fetchone()
            
            # Prepare WebSocket message payload
            websocket_message = {
                'type': 'update_message',
                'message': {
                    'id': updated_message['id'],
                    'content': message_data['content'],
                    'time_stamp': updated_message['time_stamp'].isoformat(),
                    'sent_by_user_id': user_id,
                    'sender_first_name': sender['first_name'],
                    'sender_last_name': sender['last_name']
                }
            }
            
            # Send WebSocket message
            send_websocket_message(updated_message['received_by_user_id'], websocket_message)
            
            cur.connection.commit()
            return response(200, {'message': 'Message updated successfully'})
        else:
            return response(404, {'error': 'Message not found or you are not authorized to update it'})
            
    except Exception as e:
        cur.connection.rollback()
        print(f"Error in update_message: {str(e)}")
        return response(500, {'error': 'An error occurred while updating the message'})

@authenticate
def delete_message(event, cur):
    user_id = event['requestContext']['authorizer']['claims']['sub']
    message_id = event['pathParameters']['id']
    
    try:
        # Get message details before deletion
        cur.execute("""
            SELECT received_by_user_id
            FROM message
            WHERE id = %s AND sent_by_user_id = %s
        """, (message_id, user_id))
        
        message = cur.fetchone()
        
        if message:
            # Delete the message
            cur.execute("""
                DELETE FROM message
                WHERE id = %s AND sent_by_user_id = %s
            """, (message_id, user_id))
            
            # Prepare WebSocket message payload
            websocket_message = {
                'type': 'delete_message',
                'message': {
                    'id': message_id
                }
            }
            
            # Send WebSocket message
            send_websocket_message(message['received_by_user_id'], websocket_message)
            
            cur.connection.commit()
            return response(200, {'message': 'Message deleted successfully'})
        else:
            return response(404, {'error': 'Message not found or you are not authorized to delete it'})
            
    except Exception as e:
        cur.connection.rollback()
        print(f"Error in delete_message: {str(e)}")
        return response(500, {'error': 'An error occurred while deleting the message'})

def send_websocket_message(recipient_id, message_data):
    try:
        # Get active connections for the recipient
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT connection_id
                FROM connections
                WHERE user_id = %s
            """, (recipient_id,))
            connections = cur.fetchall()

        # Initialize API Gateway Management API client
        api_client = boto3.client('apigatewaymanagementapi', 
                                endpoint_url=get_websocket_endpoint())

        # Send message to all active connections
        for connection in connections:
            try:
                api_client.post_to_connection(
                    ConnectionId=connection['connection_id'],
                    Data=json.dumps(message_data).encode('utf-8')
                )
            except Exception as e:
                if 'GoneException' in str(e):
                    # Remove stale connection
                    with conn.cursor() as cur:
                        cur.execute("""
                            DELETE FROM connections
                            WHERE connection_id = %s
                        """, (connection['connection_id'],))
                        conn.commit()
                else:
                    print(f"Error sending message to connection {connection['connection_id']}: {str(e)}")
    except Exception as e:
        print(f"Error in send_websocket_message: {str(e)}")
    finally:
        if conn:
            conn.close()

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