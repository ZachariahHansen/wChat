# functions/auth/forgot_password.py
import json
import os
import secrets
import boto3
from datetime import datetime, timedelta
import psycopg2
from psycopg2.extras import RealDictCursor

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
        email = body.get('email')
        
        if not email:
            return response(400, {'error': 'Email is required'})
            
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Check if user exists
                cur.execute('SELECT id, email, first_name FROM "user" WHERE email = %s', (email,))
                user = cur.fetchone()
                
                if not user:
                    # Return success even if email doesn't exist (security best practice)
                    return response(200, {'message': 'If an account exists with this email, you will receive reset instructions.'})
                
                # Generate reset token
                reset_token = secrets.token_urlsafe(32)
                expires_at = datetime.utcnow() + timedelta(hours=1)
                
                # Store reset token in database
                cur.execute("""
                    INSERT INTO password_reset_tokens (user_id, token, expires_at)
                    VALUES (%s, %s, %s)
                """, (user['id'], reset_token, expires_at))
                
                # Prepare reset link
                reset_link = f"{os.environ['APP_URL'].rstrip('/')}/reset-password?token={reset_token}"
                
                # Send email using AWS SES
                ses = boto3.client('ses', region_name=os.environ.get('SES_REGION', 'us-east-2'))
                
                email_body = f"""
                Hello {user['first_name']},

                You recently requested to reset your password for your WorkChat account.
                Click the link below to reset it:

                {reset_link}

                This link will expire in 1 hour.

                If you did not request this reset, please ignore this email.

                Best regards,
                WorkChat Team
                """
                
                ses.send_email(
                    Source=os.environ.get('SES_SENDER_EMAIL', 'noreply@zachariahhansen.com'),
                    Destination={
                        'ToAddresses': [email]
                    },
                    Message={
                        'Subject': {
                            'Data': 'Reset Your WorkChat Password'
                        },
                        'Body': {
                            'Text': {
                                'Data': email_body
                            }
                        }
                    }
                )
                
                conn.commit()
                return response(200, {'message': 'If an account exists with this email, you will receive reset instructions.'})
                
        finally:
            conn.close()
            
    except Exception as e:
        print(f"Error processing password reset request: {str(e)}")
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
