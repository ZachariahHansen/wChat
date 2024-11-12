# auth.py (place this in a shared location accessible to all your Lambdas)
import json
import os
import jwt
from datetime import datetime, timedelta
from functools import wraps

JWT_SECRET = os.environ['JWT_SECRET']
JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION_DELTA = timedelta(days=1)

def create_token(user_id):
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + JWT_EXPIRATION_DELTA
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_token(token):
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload['user_id']
    except jwt.ExpiredSignatureError:
        return None  # Token has expired
    except jwt.InvalidTokenError:
        return None  # Invalid token

def authenticate(func):
    @wraps(func)
    def wrapper(event, context):
        token = event.get('headers', {}).get('Authorization')
        if not token:
            return {
                'statusCode': 401,
                'body': json.dumps({'error': 'No token provided'})
            }

        user_id = verify_token(token.split(' ')[1] if token.startswith('Bearer ') else token)
        if not user_id:
            return {
                'statusCode': 401,
                'body': json.dumps({'error': 'Invalid or expired token'})
            }

        # Add user_id to the event for the wrapped function to use
        event['user_id'] = user_id
        return func(event, context)
    return wrapper