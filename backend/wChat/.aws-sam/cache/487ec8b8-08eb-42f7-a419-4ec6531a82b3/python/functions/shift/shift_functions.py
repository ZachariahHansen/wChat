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

# Custom JSON encoder to handle datetime objects
class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        return super(DateTimeEncoder, self).default(obj)

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            http_method = event['httpMethod']
            
            if http_method == 'GET':
                return get_shift(event, cur)
            elif http_method == 'POST':
                return create_shift(event, cur)
            elif http_method == 'PUT':
                return update_shift(event, cur)
            elif http_method == 'DELETE':
                return delete_shift(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def get_shift(event, cur):
    shift_id = event['pathParameters']['id']
    cur.execute("""
        SELECT s.id, s.start_time, s.end_time, s.status, 
               s.scheduled_by_id, u.first_name || ' ' || u.last_name AS scheduled_by_name,
               s.department_id, d.name AS department_name,
               s.user_id, u2.first_name || ' ' || u2.last_name AS assigned_user_name
        FROM shift s
        LEFT JOIN "user" u ON s.scheduled_by_id = u.id
        LEFT JOIN department d ON s.department_id = d.id
        LEFT JOIN "user" u2 ON s.user_id = u2.id
        WHERE s.id = %s
    """, (shift_id,))
    shift = cur.fetchone()
    
    if shift:
        return response(200, shift)
    else:
        return response(404, {'error': 'Shift not found'})

@authenticate
def create_shift(event, cur):
    shift_data = json.loads(event['body'])
    required_fields = ['start_time', 'end_time', 'scheduled_by_id', 'department_id']
    
    if not all(field in shift_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    # Convert string dates to datetime objects
    start_time = datetime.fromisoformat(shift_data['start_time'])
    end_time = datetime.fromisoformat(shift_data['end_time'])
    
    try:
        cur.execute("""
            INSERT INTO shift (start_time, end_time, scheduled_by_id, department_id, user_id, status)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (start_time, end_time, shift_data['scheduled_by_id'], 
              shift_data['department_id'], shift_data.get('user_id'), shift_data.get('status', 'scheduled')))
        
        new_shift_id = cur.fetchone()['id']
        
        # Get department name for notification
        cur.execute("SELECT name FROM department WHERE id = %s", (shift_data['department_id'],))
        department = cur.fetchone()
        
        notification_service = NotificationService()
        shift_date = start_time.strftime('%B %d, %Y')
        shift_start = start_time.strftime('%I:%M %p')
        shift_end = end_time.strftime('%I:%M %p')
        
        if shift_data.get('user_id'):
            # Notify assigned user
            notification_content = f"New shift assigned: {shift_date} from {shift_start} to {shift_end}"
            notification_service.create_notification(shift_data['user_id'], notification_content)
        else:
            # Notify department about available shift
            notification_content = f"A new shift is available: {shift_date} from {shift_start} to {shift_end}"
            notification_service.notify_department(shift_data['department_id'], notification_content)
        
        cur.connection.commit()
        return response(201, {'id': new_shift_id})
        
    except psycopg2.Error as e:
        cur.connection.rollback()
        return response(400, {'error': str(e)})

@authenticate
def update_shift(event, cur):
    shift_id = event['pathParameters']['id']
    shift_data = json.loads(event['body'])
    
    # Get current shift data for comparison
    cur.execute("""
        SELECT s.*, u.id as current_user_id
        FROM shift s
        LEFT JOIN "user" u ON s.user_id = u.id
        WHERE s.id = %s
    """, (shift_id,))
    current_shift = cur.fetchone()
    
    if not current_shift:
        return response(404, {'error': 'Shift not found'})
    
    update_fields = []
    update_values = []
    
    for field in ['start_time', 'end_time', 'scheduled_by_id', 'department_id', 'user_id', 'status']:
        if field in shift_data:
            if field in ['start_time', 'end_time']:
                shift_data[field] = datetime.fromisoformat(shift_data[field])
            update_fields.append(f"{field} = %s")
            update_values.append(shift_data[field])
    
    if not update_fields:
        return response(400, {'error': 'No fields to update'})
    
    update_values.append(shift_id)
    
    try:
        cur.execute(f"""
            UPDATE shift
            SET {', '.join(update_fields)}
            WHERE id = %s
            RETURNING *
        """, tuple(update_values))
        
        updated_shift = cur.fetchone()
        
        if updated_shift:
            notification_service = NotificationService()
            shift_date = updated_shift['start_time'].strftime('%B %d, %Y')
            
            # If user assignment changed
            if 'user_id' in shift_data:
                if current_shift['user_id'] and current_shift['user_id'] != shift_data['user_id']:
                    # Notify previous user about unassignment
                    unassign_content = f"Your shift on {shift_date} has been unassigned"
                    notification_service.create_notification(current_shift['user_id'], unassign_content)
                
                if shift_data['user_id']:
                    # Notify new user about assignment
                    assign_content = f"New shift assigned: {shift_date} from {updated_shift['start_time'].strftime('%I:%M %p')} to {updated_shift['end_time'].strftime('%I:%M %p')}"
                    notification_service.create_notification(shift_data['user_id'], assign_content)
            
            # If time changed and user is assigned
            elif ('start_time' in shift_data or 'end_time' in shift_data) and updated_shift['user_id']:
                change_content = f"Your shift on {shift_date} has been updated: {updated_shift['start_time'].strftime('%I:%M %p')} to {updated_shift['end_time'].strftime('%I:%M %p')}"
                notification_service.create_notification(updated_shift['user_id'], change_content)
            
            cur.connection.commit()
            return response(200, {'message': 'Shift updated successfully'})
        else:
            return response(404, {'error': 'Shift not found'})
            
    except psycopg2.Error as e:
        cur.connection.rollback()
        return response(400, {'error': str(e)})

@authenticate
def delete_shift(event, cur):
    shift_id = event['pathParameters']['id']
    
    # Get shift details before deletion
    cur.execute("""
        SELECT s.*, u.id as user_id
        FROM shift s
        LEFT JOIN "user" u ON s.user_id = u.id
        WHERE s.id = %s
    """, (shift_id,))
    shift = cur.fetchone()
    
    if not shift:
        return response(404, {'error': 'Shift not found'})
    
    try:
        cur.execute('DELETE FROM shift WHERE id = %s RETURNING id', (shift_id,))
        deleted_shift = cur.fetchone()
        
        if deleted_shift:
            # If shift was assigned to a user, notify them
            if shift['user_id']:
                notification_service = NotificationService()
                shift_date = shift['start_time'].strftime('%B %d, %Y')
                notification_content = f"Your shift on {shift_date} has been cancelled"
                notification_service.create_notification(shift['user_id'], notification_content)
            
            cur.connection.commit()
            return response(200, {'message': 'Shift deleted successfully'})
        else:
            return response(404, {'error': 'Shift not found'})
            
    except psycopg2.Error as e:
        cur.connection.rollback()
        return response(400, {'error': str(e)})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET,PUT,DELETE"
        },
        'body': json.dumps(body, cls=DateTimeEncoder)
    }
