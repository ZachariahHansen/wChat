import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
import jwt
from datetime import datetime, timedelta
import bcrypt
from functions.auth_layer.auth import authenticate

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']

# JWT configuration
JWT_SECRET = os.environ['JWT_SECRET']
JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION_HOURS = 24

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD
    )

def lambda_handler(event, context):
    # Add debug logging
    print("Received event:", json.dumps(event))
    
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')

    if event['httpMethod'] != 'POST':
        return response(405, {'error': 'Method not allowed'})

    try:
        print("Request body:", event.get('body'))
        body = json.loads(event['body'])
        print("Parsed body:", body)
        email = body['email']
        password = body['password']
    except (KeyError, json.JSONDecodeError) as e:
        print("Error parsing request body:", str(e))
        return response(400, {'error': 'Invalid request body', 'details': str(e)})

    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Updated query to include is_manager from user table
            cur.execute("""
                SELECT u.id, u.password, u.first_name, u.last_name, u.email, 
                       r.name as role, u.is_manager
                FROM "user" u
                JOIN role r ON u.role_id = r.id
                WHERE u.email = %s
            """, (email,))
            user = cur.fetchone()
            print("Found user:", user is not None)

            if user and bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
                token = generate_jwt_token(user)
                return response(200, {'token': token})
            else:
                return response(401, {'error': 'Invalid credentials'})
    finally:
        conn.close()

def generate_jwt_token(user):
    payload = {
        'user_id': user['id'],
        'email': user['email'],
        'first_name': user['first_name'],
        'last_name': user['last_name'],
        'role': user['role'],
        'is_manager': user['is_manager'],  # Use the actual is_manager value from the database
        'exp': datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,POST'
        },
        'body': json.dumps(body)
    }