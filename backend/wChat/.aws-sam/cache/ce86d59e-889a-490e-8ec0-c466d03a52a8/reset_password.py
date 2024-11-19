# functions/auth/reset_password.py
import json
import os
import bcrypt
import psycopg2
from psycopg2.extras import RealDictCursor
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

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    if event['httpMethod'] != 'POST':
        return response(405, {'error': 'Method not allowed'})
    
    try:
        body = json.loads(event['body'])
        token = body.get('token')
        new_password = body.get('new_password')
        
        if not token or not new_password:
            return response(400, {'error': 'Token and new password are required'})
        
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get valid reset token
                cur.execute("""
                    SELECT user_id 
                    FROM password_reset_tokens 
                    WHERE token = %s 
                    AND expires_at > CURRENT_TIMESTAMP 
                    AND used_at IS NULL
                """, (token,))
                
                token_data = cur.fetchone()
                if not token_data:
                    return response(400, {'error': 'Invalid or expired reset token'})
                
                # Hash new password
                password_hash = bcrypt.hashpw(
                    new_password.encode('utf-8'), 
                    bcrypt.gensalt()
                ).decode('utf-8')
                
                # Update password and mark token as used
                cur.execute("""
                    UPDATE "user" 
                    SET password = %s, 
                        updated_at = CURRENT_TIMESTAMP 
                    WHERE id = %s
                """, (password_hash, token_data['user_id']))
                
                cur.execute("""
                    UPDATE password_reset_tokens 
                    SET used_at = CURRENT_TIMESTAMP 
                    WHERE token = %s
                """, (token,))
                
                conn.commit()
                return response(200, {'message': 'Password reset successfully'})
                
        finally:
            conn.close()
            
    except Exception as e:
        print(f"Error processing password reset: {str(e)}")
        return response(500, {'error': 'Internal server error'})

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