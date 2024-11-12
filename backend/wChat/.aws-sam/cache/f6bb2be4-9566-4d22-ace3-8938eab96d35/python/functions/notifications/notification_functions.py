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

class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            
            if http_method == 'GET':
                return get_notifications(event, cur)
            elif http_method == 'PUT':
                return mark_notifications_read(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def get_notifications(event, cur):
    try:
        # Get query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        user_id = query_params.get('userId')
        limit = query_params.get('limit', '50')  # Default to 50 notifications
        offset = query_params.get('offset', '0')  # Default to first page
        unread_only = query_params.get('unreadOnly', 'false').lower() == 'true'
        
        if not user_id:
            return response(400, {'error': 'userId is required'})
            
        # Validate limit and offset are integers
        try:
            limit = int(limit)
            offset = int(offset)
        except ValueError:
            return response(400, {'error': 'Invalid limit or offset value'})
        
        # Build query
        query = """
            SELECT id, content, time_stamp, is_read
            FROM notification
            WHERE user_id = %s
        """
        params = [user_id]
        
        # Add unread filter if requested
        if unread_only:
            query += " AND is_read = false"
            
        # Add ordering and pagination
        query += """
            ORDER BY time_stamp DESC
            LIMIT %s OFFSET %s
        """
        params.extend([limit, offset])
        
        # Get total count for pagination
        count_query = "SELECT COUNT(*) FROM notification WHERE user_id = %s"
        count_params = [user_id]
        if unread_only:
            count_query += " AND is_read = false"
            
        cur.execute(count_query, count_params)
        total_count = cur.fetchone()['count']
        
        # Get notifications
        cur.execute(query, params)
        notifications = cur.fetchall()
        
        # Prepare response with pagination info
        response_data = {
            'notifications': notifications,
            'pagination': {
                'total': total_count,
                'limit': limit,
                'offset': offset,
                'hasMore': (offset + limit) < total_count
            }
        }
        
        return response(200, response_data)
        
    except Exception as e:
        print(f"Error retrieving notifications: {str(e)}")
        return response(500, {'error': 'Internal server error'})

@authenticate
def mark_notifications_read(event, cur):
    try:
        # Get request body
        body = json.loads(event['body'])
        user_id = body.get('userId')
        notification_ids = body.get('notificationIds', [])  # Optional: specific notifications to mark as read
        
        if not user_id:
            return response(400, {'error': 'userId is required'})
            
        # Build update query
        if notification_ids:
            # Mark specific notifications as read
            cur.execute("""
                UPDATE notification
                SET is_read = true
                WHERE user_id = %s AND id = ANY(%s)
                RETURNING id
            """, (user_id, notification_ids))
        else:
            # Mark all notifications as read
            cur.execute("""
                UPDATE notification
                SET is_read = true
                WHERE user_id = %s AND is_read = false
                RETURNING id
            """, (user_id,))
            
        updated_ids = [row['id'] for row in cur.fetchall()]
        cur.connection.commit()
        
        return response(200, {
            'message': 'Notifications marked as read',
            'updatedIds': updated_ids
        })
        
    except Exception as e:
        cur.connection.rollback()
        print(f"Error marking notifications as read: {str(e)}")
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,GET,PUT'
        },
        'body': json.dumps(body, cls=DateTimeEncoder)
    }