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
        user_id = body.get('user_id')
       
        if not shift_id or not user_id:
            return response(400, {'error': 'shift_id and user_id are required in the request body'})
       
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                return assign_user_to_shift(shift_id, user_id, cur)
        finally:
            conn.close()
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON in request body'})
    except Exception as e:
        return response(500, {'error': str(e)})

def assign_user_to_shift(shift_id, user_id, cur):
    try:
        # Get current shift details including department
        cur.execute("""
            SELECT s.*, d.name as department_name, 
                   COALESCE(u.id, 0) as current_user_id,
                   u.first_name || ' ' || u.last_name as current_user_name
            FROM shift s
            LEFT JOIN department d ON s.department_id = d.id
            LEFT JOIN "user" u ON s.user_id = u.id
            WHERE s.id = %s
        """, (shift_id,))
        shift = cur.fetchone()
        
        if not shift:
            return response(404, {'error': 'Shift not found'})

        # Check if the user exists and get their name
        cur.execute("""
            SELECT id, first_name || ' ' || last_name as full_name 
            FROM "user" 
            WHERE id = %s
        """, (user_id,))
        user = cur.fetchone()
        
        if not user:
            return response(404, {'error': 'User not found'})

        # Initialize notification service
        notification_service = NotificationService()
        
        # Format shift date and time for notifications
        shift_date = shift['start_time'].strftime('%B %d, %Y')
        shift_start = shift['start_time'].strftime('%I:%M %p')
        shift_end = shift['end_time'].strftime('%I:%M %p')

        # If shift was previously assigned to someone else
        if shift['current_user_id'] and shift['current_user_id'] != user_id:
            # Notify previous user about unassignment
            unassign_content = f"Your shift on {shift_date} ({shift_start} to {shift_end}) has been reassigned to {user['full_name']}"
            notification_service.create_notification(shift['current_user_id'], unassign_content)

        # Assign the user to the shift
        cur.execute("""
            UPDATE shift
            SET user_id = %s,
                status = 'scheduled'
            WHERE id = %s
            RETURNING id, user_id
        """, (user_id, shift_id))
        
        updated_shift = cur.fetchone()
        
        if updated_shift:
            # Notify new user about assignment
            assign_content = f"You have been assigned a shift on {shift_date} from {shift_start} to {shift_end}"
            if shift['department_name']:
                assign_content += f" in {shift['department_name']}"
            
            notification_service.create_notification(user_id, assign_content)
            
            # Notify department managers
            cur.execute("""
                SELECT DISTINCT u.id
                FROM "user" u
                JOIN department_group dg ON u.id = dg.user_id
                WHERE dg.department_id = %s AND u.is_manager = true
            """, (shift['department_id'],))
            
            managers = cur.fetchall()
            manager_notification = f"{user['full_name']} has been assigned to the shift on {shift_date} ({shift_start} to {shift_end})"
            
            for manager in managers:
                notification_service.create_notification(manager['id'], manager_notification)
            
            cur.connection.commit()
            return response(200, {
                'message': 'User assigned to shift successfully', 
                'shift_id': updated_shift['id'], 
                'user_id': updated_shift['user_id']
            })
        else:
            return response(500, {'error': 'Failed to assign user to shift'})
            
    except Exception as e:
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