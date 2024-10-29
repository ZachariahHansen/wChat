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
            
            if http_method == 'POST':
                return assign_user_to_department(event, cur)
            elif http_method == 'DELETE':
                return remove_user_from_department(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def assign_user_to_department(event, cur):
    assignment_data = json.loads(event['body'])
    required_fields = ['user_id', 'department_id']
    
    if not all(field in assignment_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    # Verify user exists
    cur.execute('SELECT id FROM "user" WHERE id = %s', (assignment_data['user_id'],))
    if not cur.fetchone():
        return response(404, {'error': 'User not found'})
    
    # Verify department exists
    cur.execute('SELECT id FROM department WHERE id = %s', (assignment_data['department_id'],))
    if not cur.fetchone():
        return response(404, {'error': 'Department not found'})
    
    # Check if assignment already exists
    cur.execute("""
        SELECT * FROM department_group 
        WHERE user_id = %s AND department_id = %s
    """, (assignment_data['user_id'], assignment_data['department_id']))
    
    if cur.fetchone():
        return response(409, {'error': 'User is already assigned to this department'})
    
    # Create the assignment
    cur.execute("""
        INSERT INTO department_group (user_id, department_id)
        VALUES (%s, %s)
        RETURNING department_id
    """, (assignment_data['user_id'], assignment_data['department_id']))
    
    cur.connection.commit()
    
    return response(201, {
        'message': 'User assigned to department successfully',
        'user_id': assignment_data['user_id'],
        'department_id': assignment_data['department_id']
    })

@authenticate
def remove_user_from_department(event, cur):
    # Expecting path parameters: /departments/{departmentId}/user/{userId}
    department_id = event['pathParameters']['department_id']
    user_id = event['pathParameters']['user_id']
    
    cur.execute("""
        DELETE FROM department_group 
        WHERE department_id = %s AND user_id = %s
        RETURNING department_id
    """, (department_id, user_id))
    
    deleted_assignment = cur.fetchone()
    cur.connection.commit()
    
    if deleted_assignment:
        return response(200, {'message': 'User removed from department successfully'})
    else:
        return response(404, {'error': 'Assignment not found'})

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