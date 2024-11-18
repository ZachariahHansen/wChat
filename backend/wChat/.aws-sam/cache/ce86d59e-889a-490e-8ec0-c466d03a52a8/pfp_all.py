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

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD
    )

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
        
    if event['httpMethod'] != 'GET':
        return response(405, {'error': 'Method not allowed'})
        
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            return get_all_profile_pictures(event, cur)
    finally:
        conn.close()

@authenticate
def get_all_profile_pictures(event, cur):
    try:
        # Fetch all users with profile pictures
        cur.execute("""
            SELECT id as user_id, profile_picture, profile_picture_content_type
            FROM "user"
            WHERE profile_picture IS NOT NULL
            ORDER BY id
        """)
        
        results = cur.fetchall()
        if not results:
            return response(404, {'error': 'No profile pictures found'})

        # Process each result
        profile_pictures = []
        for result in results:
            # Convert image data to bytes if needed
            image_data = result['profile_picture']
            if isinstance(image_data, memoryview):
                image_data = image_data.tobytes()
            
            # Create profile picture object
            profile_picture = {
                'user_id': result['user_id'],
                'content_type': result['profile_picture_content_type'],
                'image_data': base64.b64encode(image_data).decode('utf-8')
            }
            profile_pictures.append(profile_picture)
        
        # Return the array of profile pictures
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET'
            },
            'body': json.dumps({
                'profile_pictures': profile_pictures
            })
        }
        
    except Exception as e:
        print(f"Error retrieving profile pictures: {str(e)}")
        import traceback
        print("Traceback:", traceback.format_exc())
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,GET'
        },
        'body': json.dumps(body)
    }