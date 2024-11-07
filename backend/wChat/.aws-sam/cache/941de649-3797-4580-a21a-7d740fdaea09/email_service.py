import json
import os
import boto3
import logging
from botocore.exceptions import ClientError
from functions.auth_layer.auth import authenticate
import psycopg2
from psycopg2.extras import RealDictCursor

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS SES client
ses = boto3.client('ses', region_name=os.environ['MY_AWS_REGION'])

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

class EmailTemplate:
    @staticmethod
    def new_user(user_name, temp_password):
        logger.info("new_user template function called")  # Log A
        logger.info(f"Parameters received - user_name: {user_name}, temp_password: {temp_password}")  # Log B

        email_content = {
            'subject': 'Welcome to WorkChat - Your Account Details',
            'body': f"""
            Hello {user_name},

            Welcome to WorkChat! Your account has been created successfully.

            Please log into WorkChat using the following temporary password:
            {temp_password}

            IMPORTANT SECURITY INFORMATION:
            - This temporary password will expire in 24 hours
            - You will be required to change your password upon first login
            - Your new password must meet our security requirements

            You can log in at: {os.environ.get('APP_URL', '[WorkChat URL]')}

            If you did not request this account, please contact your administrator 
            immediately at {os.environ.get('SUPPORT_EMAIL', 'support@workchat.com')}.

            Best regards,
            WorkChat Team

            This is an automated message, please do not reply.
            """
        }

        logger.info("Email content generated successfully")  # Log C
        return email_content

    @staticmethod
    def validate_template_data(template_type, template_data):
        """Validate that all required fields for a template are present."""
        template_requirements = {
            'new_user': ['user_name', 'temp_password'],
            'shift_assignment': ['user_name', 'shift_date', 'start_time', 'end_time', 'department'],
            'shift_exchange_request': ['requester_name', 'shift_date', 'start_time', 'end_time']
        }
        
        required_fields = template_requirements.get(template_type)
        if not required_fields:
            raise ValueError(f"Invalid template type: {template_type}")
            
        missing_fields = [
            field for field in required_fields 
            if field not in template_data
        ]
        
        if missing_fields:
            raise ValueError(f"Missing required template fields: {missing_fields}")

def verify_email_address(email):
    """Verify if an email address is verified in SES."""
    try:
        verification_attrs = ses.get_identity_verification_attributes(
            Identities=[email]
        )
        status = verification_attrs['VerificationAttributes'].get(email, {}).get('VerificationStatus')
        return status == 'Success'
    except ClientError as e:
        logger.error(f"Error verifying email address: {str(e)}")
        return False

def lambda_handler(event, context):
    logger.info("Starting lambda_handler")
    logger.info(f"Received event: {json.dumps(event)}")  # Log the incoming event
    
    if event['httpMethod'] == 'OPTIONS':
        logger.info("Handling OPTIONS request")
        return response(200, 'OK')
    
    logger.info("Getting DB connection")
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            logger.info(f"Processing {event['httpMethod']} request")
            if event['httpMethod'] == 'POST':
                logger.info("Calling send_email function")
                return send_email(event, cur)
            else:
                logger.info(f"Method not allowed: {event['httpMethod']}")
                return response(405, {'error': 'Method not allowed'})
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return response(500, {'error': 'Internal server error'})
    finally:
        logger.info("Closing DB connection")
        conn.close()

def send_email(event, cur):
    try:
        logger.info("Starting send_email function")  # Log 1
        email_data = json.loads(event['body'])
        logger.info(f"Email data received: {email_data}")  # Log 2
        
        # Validate required fields
        required_fields = ['template_type', 'recipient_id', 'template_data']
        logger.info(f"Checking required fields: {required_fields}")  # Log 3
        missing_fields = [field for field in required_fields if field not in email_data]
        if missing_fields:
            logger.error(f"Missing fields: {missing_fields}")
            return response(400, {
                'error': 'Missing required fields',
                'missing_fields': missing_fields
            })
        
        logger.info("All required fields present")  # Log 4
        
        # Validate template data
        try:
            logger.info("Validating template data")  # Log 5
            EmailTemplate.validate_template_data(
                email_data['template_type'], 
                email_data['template_data']
            )
            logger.info("Template data validated successfully")  # Log 6
        except ValueError as e:
            logger.error(f"Template validation error: {str(e)}")
            return response(400, {'error': str(e)})
        
        # Get recipient email from database
        logger.info(f"Fetching recipient with ID: {email_data['recipient_id']}")  # Log 7
        cur.execute("""
            SELECT email, first_name, last_name 
            FROM "user" 
            WHERE id = %s
        """, (email_data['recipient_id'],))
        
        recipient = cur.fetchone()
        logger.info(f"Recipient data: {recipient}")  # Log 8
        
        if not recipient:
            logger.warning(f"Recipient not found: {email_data['recipient_id']}")
            return response(404, {'error': 'Recipient not found'})
        
        # Get template content
        logger.info(f"Getting template for type: {email_data['template_type']}")  # Log 9
        template_func = getattr(EmailTemplate, email_data['template_type'], None)
        if not template_func:
            logger.error(f"Invalid template type: {email_data['template_type']}")
            return response(400, {'error': 'Invalid template type'})
        
        # Generate email content
        logger.info("Generating email content")  # Log 10
        logger.info(f"Template data being used: {email_data['template_data']}")  # Log 11
        email_content = template_func(**email_data['template_data'])
        logger.info("Email content generated")  # Log 12
        
        # Send email using AWS SES
        try:
            logger.info(f"Attempting to send email to {recipient['email']}")  # Log 13
            logger.info(f"Using sender email: {os.environ['SENDER_EMAIL']}")  # Log 14
            
            response_ses = ses.send_email(
                Source=os.environ['SENDER_EMAIL'],
                Destination={
                    'ToAddresses': [recipient['email']]
                },
                Message={
                    'Subject': {
                        'Data': email_content['subject']
                    },
                    'Body': {
                        'Text': {
                            'Data': email_content['body']
                        }
                    }
                }
            )
            
            logger.info(f"SES Response: {response_ses}")  # Log 15
            
            # Store notification in database
            logger.info("Storing notification in database")  # Log 16
            cur.execute("""
                INSERT INTO notification (content, time_stamp, user_id)
                VALUES (%s, CURRENT_TIMESTAMP, %s)
                RETURNING id
            """, (f"Email sent: {email_content['subject']}", email_data['recipient_id']))
            
            notification_id = cur.fetchone()['id']
            cur.connection.commit()
            
            logger.info(f"Email sent successfully to user ID: {email_data['recipient_id']}")
            return response(200, {
                'message': 'Email sent successfully',
                'messageId': response_ses['MessageId'],
                'notificationId': notification_id
            })
            
        except ClientError as e:
            logger.error(f"SES Error: {str(e)}")
            logger.error(f"Error Response: {e.response if hasattr(e, 'response') else 'No response'}")
            return response(500, {'error': 'Failed to send email', 'details': str(e)})
            
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
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