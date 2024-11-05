import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
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

@authenticate
def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    if event['httpMethod'] != 'GET':
        return response(405, {'error': 'Method not allowed'})

    try:
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get query parameters
                params = event.get('queryStringParameters', {}) or {}
                
                # Extract filter parameters
                department_id = params.get('department_id')
                user_id = params.get('user_id')
                status = params.get('status')
                start_date = params.get('start_date')
                end_date = params.get('end_date')
                limit = params.get('limit', '100')  # Default to 100 shifts
                offset = params.get('offset', '0')  # Default to first page
                
                return get_shifts(
                    cur, 
                    department_id=department_id,
                    user_id=user_id,
                    status=status,
                    start_date=start_date,
                    end_date=end_date,
                    limit=limit,
                    offset=offset
                )
        finally:
            conn.close()
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': str(e)})

def get_shifts(cur, department_id=None, user_id=None, status=None, 
               start_date=None, end_date=None, limit=100, offset=0):
    """
    Get shifts with optional filtering
    """
    try:
        # Base query
        query = """
            SELECT 
                s.id,
                s.start_time,
                s.end_time,
                s.scheduled_by_id,
                s.department_id,
                s.user_id,
                s.status,
                d.name as department_name,
                u.first_name as user_first_name,
                u.last_name as user_last_name,
                sb.first_name as scheduled_by_first_name,
                sb.last_name as scheduled_by_last_name
            FROM shift s
            LEFT JOIN department d ON s.department_id = d.id
            LEFT JOIN "user" u ON s.user_id = u.id
            LEFT JOIN "user" sb ON s.scheduled_by_id = sb.id
            WHERE 1=1
        """
        
        # Initialize parameters list
        params = []
        
        # Add filters if provided
        if department_id:
            query += " AND s.department_id = %s"
            params.append(department_id)
            
        if user_id:
            query += " AND s.user_id = %s"
            params.append(user_id)
            
        if status:
            query += " AND s.status = %s"
            params.append(status)
            
        if start_date:
            query += " AND s.start_time >= %s"
            params.append(start_date)
            
        if end_date:
            query += " AND s.end_time <= %s"
            params.append(end_date)
            
        # Add ordering
        query += " ORDER BY s.start_time ASC"
        
        # Add pagination
        query += " LIMIT %s OFFSET %s"
        params.extend([limit, offset])
        
        # Execute query
        cur.execute(query, params)
        shifts = cur.fetchall()
        
        # Get total count for pagination
        count_query = """
            SELECT COUNT(*) as total
            FROM shift s
            WHERE 1=1
        """
        
        # Add the same filters to count query
        params = params[:-2]  # Remove limit and offset
        if department_id:
            count_query += " AND s.department_id = %s"
        if user_id:
            count_query += " AND s.user_id = %s"
        if status:
            count_query += " AND s.status = %s"
        if start_date:
            count_query += " AND s.start_time >= %s"
        if end_date:
            count_query += " AND s.end_time <= %s"
            
        cur.execute(count_query, params)
        total_count = cur.fetchone()['total']
        
        return response(200, {
            'shifts': shifts,
            'pagination': {
                'total': total_count,
                'limit': int(limit),
                'offset': int(offset)
            }
        })
        
    except Exception as e:
        print(f"Error in get_shifts: {str(e)}")
        return response(500, {'error': str(e)})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,GET'
        },
        'body': json.dumps(body, default=str)  # default=str handles datetime serialization
    }