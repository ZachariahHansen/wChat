import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor


DB_HOST = os.environ['DB_HOST']
# DB_NAME = 'users' 
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        # database=DB_NAME,
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
                return get_role(event, cur)
            elif http_method == 'POST':
                return create_role(event, cur)
            elif http_method == 'PUT':
                return update_role(event, cur)
            elif http_method == 'DELETE':
                return delete_role(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

def get_role(event, cur):
    role_id = event['pathParameters']['id']
    cur.execute("SELECT * FROM role WHERE id = %s", (role_id,))
    role = cur.fetchone()
    
    if role:
        return response(200, role)
    else:
        return response(404, {'error': 'Role not found'})

def create_role(event, cur):
    role_data = json.loads(event['body'])
    required_fields = ['name', 'description']
    
    if not all(field in role_data for field in required_fields):
        return response(400, {'error': 'Missing required fields'})
    
    cur.execute("""
        INSERT INTO role (name, description)
        VALUES (%s, %s)
        RETURNING id
    """, (role_data['name'], role_data['description']))
    
    new_role_id = cur.fetchone()['id']
    cur.connection.commit()
    
    return response(201, {'id': new_role_id})

def update_role(event, cur):
    role_id = event['pathParameters']['id']
    role_data = json.loads(event['body'])
    
    update_fields = []
    update_values = []
    
    for field in ['name', 'description']:
        if field in role_data:
            update_fields.append(f"{field} = %s")
            update_values.append(role_data[field])
    
    if not update_fields:
        return response(400, {'error': 'No fields to update'})
    
    update_values.append(role_id)
    
    cur.execute(f"""
        UPDATE role
        SET {', '.join(update_fields)}
        WHERE id = %s
        RETURNING id
    """, tuple(update_values))
    
    updated_role = cur.fetchone()
    cur.connection.commit()
    
    if updated_role:
        return response(200, {'message': 'Role updated successfully'})
    else:
        return response(404, {'error': 'Role not found'})

def delete_role(event, cur):
    role_id = event['pathParameters']['id']
    
    cur.execute("DELETE FROM role WHERE id = %s RETURNING id", (role_id,))
    deleted_role = cur.fetchone()
    cur.connection.commit()
    
    if deleted_role:
        return response(200, {'message': 'Role deleted successfully'})
    else:
        return response(404, {'error': 'Role not found'})

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