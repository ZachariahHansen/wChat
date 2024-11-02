import json
import os
import base64
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate

# Database connection parameters
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']

# Constants
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB
ALLOWED_CONTENT_TYPES = {
    'image/jpeg',
    'image/png'
}

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
            if event['httpMethod'] == 'GET':
                return get_profile_picture(event, cur)
            elif event['httpMethod'] == 'PUT':
                return update_profile_picture(event, cur)
            elif event['httpMethod'] == 'DELETE':
                return delete_profile_picture(event, cur)
            else:
                return response(405, {'error': 'Method not allowed'})
    finally:
        conn.close()

@authenticate
def get_profile_picture(event, cur):
    try:
        user_id = event['pathParameters']['id']
        
        # Fetch the image data
        cur.execute("""
            SELECT profile_picture, profile_picture_content_type
            FROM "user"
            WHERE id = %s
        """, (user_id,))
        
        result = cur.fetchone()
        if not result or not result['profile_picture']:
            return response(404, {'error': 'Profile picture not found'})

        # Convert image data to bytes if needed
        image_data = result['profile_picture']
        if isinstance(image_data, memoryview):
            image_data = image_data.tobytes()
        
        # Return the image directly with proper headers
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': result['profile_picture_content_type'],
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET,PUT,DELETE'
            },
            'body': base64.b64encode(image_data).decode('utf-8'),
            'isBase64Encoded': True
        }
        
    except Exception as e:
        print(f"Error retrieving profile picture: {str(e)}")
        return response(500, {'error': 'Internal server error'})

@authenticate
def update_profile_picture(event, cur):
    try:
        # Debug logging for incoming event
        print("Full event:", json.dumps(event, default=str))
        
        user_id = event['pathParameters']['id']
        content_type = event.get('headers', {}).get('Content-Type', '')
        print(f"Content-Type: {content_type}")
        
        # Validate content type
        if not content_type:
            return response(400, {'error': 'Content-Type header is required'})
            
        if content_type not in ALLOWED_CONTENT_TYPES:
            return response(400, {
                'error': f'Invalid content type. Allowed types: {", ".join(ALLOWED_CONTENT_TYPES)}'
            })
        
        # Get body content
        body = event.get('body', '')
        is_base64 = event.get('isBase64Encoded', False)
        print(f"Is base64 encoded: {is_base64}")
        
        if not body:
            return response(400, {'error': 'No image data provided'})
        
        try:
            # Handle base64 encoded data from API Gateway
            if is_base64:
                image_data = base64.b64decode(body)
            else:
                # If somehow we got raw data, encode it first then decode
                # This handles cases where the data might be double-encoded
                try:
                    image_data = base64.b64decode(body)
                except:
                    return response(400, {
                        'error': 'Invalid image data format. Please ensure you are sending binary data through Postman.'
                    })
            
            print(f"Processed image data length: {len(image_data)} bytes")
            
            # Update the profile picture in the database
            cur.execute("""
                UPDATE "user"
                SET profile_picture = %s,
                    profile_picture_content_type = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                RETURNING id
            """, (psycopg2.Binary(image_data), content_type, user_id))
            
            updated_user = cur.fetchone()
            if not updated_user:
                return response(404, {'error': 'User not found'})
                
            cur.connection.commit()
            return response(200, {'message': 'Profile picture updated successfully'})
            
        except Exception as e:
            print(f"Error processing image data: {str(e)}")
            import traceback
            print("Traceback:", traceback.format_exc())
            return response(400, {
                'error': 'Invalid image data format',
                'details': str(e),
                'help': 'Please ensure you are using binary file upload in Postman'
            })
            
    except Exception as e:
        print(f"General error: {str(e)}")
        import traceback
        print("Traceback:", traceback.format_exc())
        return response(500, {'error': 'Internal server error', 'details': str(e)})


@authenticate
def delete_profile_picture(event, cur):
    try:
        user_id = event['pathParameters']['id']
        
        cur.execute("""
            UPDATE "user"
            SET profile_picture = NULL,
                profile_picture_content_type = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING id
        """, (user_id,))
        
        updated_user = cur.fetchone()
        if not updated_user:
            return response(404, {'error': 'User not found'})
            
        cur.connection.commit()
        return response(200, {'message': 'Profile picture deleted successfully'})
        
    except Exception as e:
        cur.connection.rollback()
        print(f"Error deleting profile picture: {str(e)}")
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,GET,PUT,DELETE'
        },
        'body': json.dumps(body) if isinstance(body, (dict, str)) else body
    }