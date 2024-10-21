import json
import os
import boto3
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
    connection_id = event['requestContext']['connectionId']
    user_id = event['queryStringParameters'].get('user_id')
    
    if not user_id:
        return {'statusCode': 400, 'body': json.dumps('Missing user_id parameter')}
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO connection (connection_id, user_id)
                VALUES (%s, %s)
            """, (connection_id, user_id))
            conn.commit()
        return {'statusCode': 200, 'body': json.dumps('Connected successfully')}
    except psycopg2.Error as e:
        print(f"Database error: {e}")
        return {'statusCode': 500, 'body': json.dumps('Failed to connect')}
    finally:
        conn.close()