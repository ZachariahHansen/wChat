import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from functions.notifications.python.notification_service import NotificationService
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

@authenticate
def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    if event['httpMethod'] != 'PUT':
        return response(405, {'error': 'Method not allowed'})

    try:
        # Parse the request body
        body = json.loads(event['body'])
        shift_id = body.get('shift_id')
        
        if not shift_id:
            return response(400, {'error': 'shift_id is required in the request body'})
        
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                return unassign_user_from_shift(shift_id, cur)
        finally:
            conn.close()
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON in request body'})
    except Exception as e:
        return response(500, {'error': str(e)})

def unassign_user_from_shift(shift_id, cur):
    # Check if the shift exists and has an assigned user
    cur.execute("""
        SELECT s.*, u.id as user_id, d.id as department_id
        FROM shift s
        LEFT JOIN "user" u ON s.user_id = u.id
        LEFT JOIN department d ON s.department_id = d.id
        WHERE s.id = %s
    """, (shift_id,))
    shift = cur.fetchone()
    
    if not shift:
        return response(404, {'error': 'Shift not found'})
    
    if shift['user_id'] is None:
        return response(400, {'error': 'Shift is already unassigned'})

    try:
        # Unassign the user from the shift by setting user_id to NULL
        cur.execute("""
            UPDATE shift
            SET user_id = NULL,
                status = 'available_for_exchange'
            WHERE id = %s
            RETURNING id, user_id, status, start_time, department_id
        """, (shift_id,))
        
        updated_shift = cur.fetchone()
        
        if updated_shift:
            notification_service = NotificationService()
            shift_date = shift['start_time'].strftime('%B %d, %Y')
            
            # Notify the user who was unassigned
            unassign_content = f"Your shift on {shift_date} has been unassigned"
            notification_service.create_notification(shift['user_id'], unassign_content)
            
            # Notify the department about the available shift
            shift_start = shift['start_time'].strftime('%I:%M %p')
            shift_end = shift['end_time'].strftime('%I:%M %p')
            available_content = f"A new shift is available: {shift_date} from {shift_start} to {shift_end}"
            notification_service.notify_department(shift['department_id'], available_content)
            
            cur.connection.commit()
            return response(200, {
                'message': 'User unassigned from shift successfully',
                'shift_id': updated_shift['id'],
                'status': updated_shift['status']
            })
        else:
            return response(500, {'error': 'Failed to unassign user from shift'})
            
    except psycopg2.Error as e:
        cur.connection.rollback()
        return response(500, {'error': str(e)})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            "Access-Control-Allow-Methods": "OPTIONS,PUT"
        },
        'body': json.dumps(body)
    }
