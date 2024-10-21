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
    message = json.loads(event['body'])['message']
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT connection_id FROM connection")
            connections = cur.fetchall()
        
        api_client = boto3.client('apigatewaymanagementapi', 
                                  endpoint_url=f"https://{event['requestContext']['domainName']}/{event['requestContext']['stage']}")
        
        for connection in connections:
            try:
                api_client.post_to_connection(
                    ConnectionId=connection['connection_id'],
                    Data=json.dumps(message).encode('utf-8')
                )
            except api_client.exceptions.GoneException:
                # Connection is no longer available, remove it from the database
                cur.execute("DELETE FROM connection WHERE connection_id = %s", (connection['connection_id'],))
                conn.commit()
        
        return {'statusCode': 200, 'body': json.dumps('Message broadcasted successfully')}
    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps('Failed to broadcast message')}
    finally:
        conn.close()