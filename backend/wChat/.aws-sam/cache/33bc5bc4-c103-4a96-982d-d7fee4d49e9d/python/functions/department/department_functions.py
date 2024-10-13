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
            
            if http_method == 'GET':
                return get_department(event, cur)
            elif http_method == 'POST':
                return create_department(event, cur)
            elif http_method == 'PUT':
                return update_department(event, cur)
            elif http_method == 'DELETE':
                return delete_department(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def get_department(event, cur):
    department_id = event['pathParameters']['id']
    cur.execute("""
        SELECT d.id, d.name, d.description, 
               array_agg(json_build_object('id', u.id, 'name', u.first_name || ' ' || u.last_name)) as users
        FROM department d
        LEFT JOIN department_group dg ON d.id = dg.department_id
        LEFT JOIN "user" u ON dg.user_id = u.id
        WHERE d.id = %s
        GROUP BY d.id, d.name, d.description
    """, (department_id,))
    department = cur.fetchone()
    
    if department:
        return response(200, department)
    else:
        return response(404, {'error': 'Department not found'})

@authenticate
def create_department(event, cur):
    department_data = json.loads(event['body'])
    required_fields = ['name']
    
    if not all(field in department_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    cur.execute("""
        INSERT INTO department (name, description)
        VALUES (%s, %s)
        RETURNING id
    """, (department_data['name'], department_data.get('description')))
    
    new_department_id = cur.fetchone()['id']
    cur.connection.commit()
    
    return response(201, {'id': new_department_id})

@authenticate
def update_department(event, cur):
    department_id = event['pathParameters']['id']
    department_data = json.loads(event['body'])
    
    update_fields = []
    update_values = []
    
    for field in ['name', 'description']:
        if field in department_data:
            update_fields.append(f"{field} = %s")
            update_values.append(department_data[field])
    
    if not update_fields:
        return response(400, {'error': 'No fields to update'})
    
    update_values.append(department_id)
    
    cur.execute(f"""
        UPDATE department
        SET {', '.join(update_fields)}
        WHERE id = %s
        RETURNING id
    """, tuple(update_values))
    
    updated_department = cur.fetchone()
    cur.connection.commit()
    
    if updated_department:
        return response(200, {'message': 'Department updated successfully'})
    else:
        return response(404, {'error': 'Department not found'})

@authenticate
def delete_department(event, cur):
    department_id = event['pathParameters']['id']
    
    # First, delete related records in department_group
    cur.execute('DELETE FROM department_group WHERE department_id = %s', (department_id,))
    
    # Then, delete the department
    cur.execute('DELETE FROM department WHERE id = %s RETURNING id', (department_id,))
    deleted_department = cur.fetchone()
    cur.connection.commit()
    
    if deleted_department:
        return response(200, {'message': 'Department deleted successfully'})
    else:
        return response(404, {'error': 'Department not found'})

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