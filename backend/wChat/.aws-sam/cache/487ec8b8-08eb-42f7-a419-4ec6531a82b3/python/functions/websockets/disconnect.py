import json
import os
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
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Delete the connection record
            cur.execute("""
                DELETE FROM connections
                WHERE connection_id = %s
            """, (connection_id,))
            deleted_rows = cur.rowcount
            conn.commit()
        
        if deleted_rows > 0:
            return {'statusCode': 200, 'body': json.dumps('Disconnected successfully')}
        else:
            return {'statusCode': 404, 'body': json.dumps('Connection not found')}
    except psycopg2.Error as e:
        print(f"Database error: {e}")
        return {'statusCode': 500, 'body': json.dumps('Failed to disconnect')}
    finally:
        conn.close()