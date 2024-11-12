import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from datetime import datetime, date
from functions.notifications.python.notification_service import NotificationService

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
        if isinstance(obj, (date, datetime)):
            return obj.isoformat()
        return super().default(obj)

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            path_parameters = event.get('pathParameters') or {}
            
            if http_method == 'GET':
                if path_parameters.get('id'):
                    return get_time_off_request(event, cur)
                else:
                    return get_time_off_requests(event, cur)
            elif http_method == 'POST':
                return create_time_off_request(event, cur)
            elif http_method == 'PUT':
                return update_time_off_request(event, cur)
            elif http_method == 'DELETE':
                return delete_time_off_request(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def get_time_off_requests(event, cur):
    # Get query parameters
    query_params = event.get('queryStringParameters', {}) or {}
    user_id = query_params.get('userId')
    status = query_params.get('status')
    
    # Base query
    query = """
        SELECT tor.*, 
               u.first_name || ' ' || u.last_name as requester_name,
               resp.first_name || ' ' || resp.last_name as responder_name
        FROM time_off_request tor
        JOIN "user" u ON tor.user_id = u.id
        LEFT JOIN "user" resp ON tor.responded_by_id = resp.id
        WHERE 1=1
    """
    params = []
    
    # Add filters
    if user_id:
        query += " AND tor.user_id = %s"
        params.append(user_id)
    
    if status:
        query += " AND tor.status = %s"
        params.append(status)
    
    # Order by requested date
    query += " ORDER BY tor.requested_at DESC"
    
    cur.execute(query, params)
    requests = cur.fetchall()
    
    return response(200, requests)

@authenticate
def get_time_off_request(event, cur):
    request_id = event['pathParameters']['id']
    
    cur.execute("""
        SELECT tor.*, 
               u.first_name || ' ' || u.last_name as requester_name,
               resp.first_name || ' ' || resp.last_name as responder_name
        FROM time_off_request tor
        JOIN "user" u ON tor.user_id = u.id
        LEFT JOIN "user" resp ON tor.responded_by_id = resp.id
        WHERE tor.id = %s
    """, (request_id,))
    
    request = cur.fetchone()
    if request:
        return response(200, request)
    else:
        return response(404, {'error': 'Time off request not found'})

@authenticate
def create_time_off_request(event, cur):
    request_data = json.loads(event['body'])
    required_fields = ['user_id', 'start_date', 'end_date', 'request_type', 'reason']
    
    # Validate required fields
    if not all(field in request_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    # Validate request_type
    valid_types = ['vacation', 'sick_leave', 'personal', 'other']
    if request_data['request_type'] not in valid_types:
        return response(400, {'error': f'Invalid request type. Must be one of: {", ".join(valid_types)}'})
    
    try:
        # Get user name for notification
        cur.execute("""
            SELECT first_name || ' ' || last_name as full_name
            FROM "user"
            WHERE id = %s
        """, (request_data['user_id'],))
        user = cur.fetchone()
        
        cur.execute("""
            INSERT INTO time_off_request 
            (user_id, start_date, end_date, request_type, reason, notes)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            request_data['user_id'],
            request_data['start_date'],
            request_data['end_date'],
            request_data['request_type'],
            request_data['reason'],
            request_data.get('notes')
        ))
        
        new_request_id = cur.fetchone()['id']
        cur.connection.commit()
        
        # Send notification to managers
        notification_service = NotificationService()
        start_date = datetime.strptime(request_data['start_date'], '%Y-%m-%d').strftime('%B %d, %Y')
        end_date = datetime.strptime(request_data['end_date'], '%Y-%m-%d').strftime('%B %d, %Y')
        
        if start_date == end_date:
            notification_content = f"New time off request from {user['full_name']} ({start_date})"
        else:
            notification_content = f"New time off request from {user['full_name']} ({start_date} to {end_date})"
        
        notification_service.notify_managers(notification_content)
        
        return response(201, {'id': new_request_id})
        
    except psycopg2.Error as e:
        cur.connection.rollback()
        return response(400, {'error': str(e)})

@authenticate
def update_time_off_request(event, cur):
    request_id = event['pathParameters']['id']
    request_data = json.loads(event['body'])
    
    # Validate status if it's being updated
    if 'status' in request_data:
        valid_statuses = ['pending', 'approved', 'denied', 'cancelled']
        if request_data['status'] not in valid_statuses:
            return response(400, {'error': f'Invalid status. Must be one of: {", ".join(valid_statuses)}'})
    
    # Build update query
    update_fields = []
    update_values = []
    
    for field in ['status', 'notes']:
        if field in request_data:
            update_fields.append(f"{field} = %s")
            update_values.append(request_data[field])
    
    if 'status' in request_data:
        update_fields.extend(['responded_at = %s', 'responded_by_id = %s'])
        update_values.extend([datetime.now(), request_data.get('responded_by_id')])
    
    if not update_fields:
        return response(400, {'error': 'No fields to update'})
    
    update_values.append(request_id)
    
    try:
        # Get request details for notification
        cur.execute("""
            SELECT tor.*, u.id as user_id
            FROM time_off_request tor
            JOIN "user" u ON tor.user_id = u.id
            WHERE tor.id = %s
        """, (request_id,))
        request = cur.fetchone()
        
        cur.execute(f"""
            UPDATE time_off_request
            SET {', '.join(update_fields)}
            WHERE id = %s
            RETURNING id
        """, tuple(update_values))
        
        updated_request = cur.fetchone()
        cur.connection.commit()
        
        if updated_request and 'status' in request_data:
            # Send notification to the requesting user
            notification_service = NotificationService()
            start_date = request['start_date'].strftime('%B %d, %Y')
            end_date = request['end_date'].strftime('%B %d, %Y')
            
            if start_date == end_date:
                notification_content = f"Your time off request for {start_date} has been {request_data['status']}"
            else:
                notification_content = f"Your time off request for {start_date} to {end_date} has been {request_data['status']}"
            
            notification_service.create_notification(request['user_id'], notification_content)
            
            return response(200, {'message': 'Time off request updated successfully'})
        elif updated_request:
            return response(200, {'message': 'Time off request updated successfully'})
        else:
            return response(404, {'error': 'Time off request not found'})
            
    except psycopg2.Error as e:
        cur.connection.rollback()
        return response(400, {'error': str(e)})

@authenticate
def delete_time_off_request(event, cur):
    request_id = event['pathParameters']['id']
    
    cur.execute('DELETE FROM time_off_request WHERE id = %s RETURNING id', (request_id,))
    deleted_request = cur.fetchone()
    cur.connection.commit()
    
    if deleted_request:
        return response(200, {'message': 'Time off request deleted successfully'})
    else:
        return response(404, {'error': 'Time off request not found'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,PUT,DELETE'
        },
        'body': json.dumps(body, cls=DateTimeEncoder)
    }
