import json
import os
import jwt
import requests
import base64
from datetime import datetime, timedelta
from functools import wraps
import cryptography.hazmat.primitives.asymmetric.rsa as rsa
from cryptography.hazmat.primitives import serialization

# Environment variables
JWT_SECRET = os.environ['JWT_SECRET']
REGION = os.environ['AWS_REGION']
USER_POOL_ID = os.environ['COGNITO_USER_POOL_ID']

# Cognito keys URL
COGNITO_JWT_KEYS_URL = f'https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}/.well-known/jwks.json'

# Cache for public keys
_COGNITO_PUBLIC_KEYS = None
_KEYS_TIMESTAMP = None
KEYS_CACHE_DURATION = timedelta(hours=24)

def import_key(jwk):
    """Convert a JWK to a format usable by the jwt library"""
    if jwk.get('kty') != 'RSA':
        raise ValueError('Only RSA keys are supported')
    
    # Extract the necessary components
    e = int.from_bytes(base64url_decode(jwk['e']), byteorder='big')
    n = int.from_bytes(base64url_decode(jwk['n']), byteorder='big')
    
    # Create the public key
    public_numbers = rsa.RSAPublicNumbers(e, n)
    public_key = public_numbers.public_key()
    
    # Convert to PEM format
    pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    
    return pem

def base64url_decode(input):
    """Decode base64url-encoded string"""
    padding = b'=' * (4 - (len(input) % 4))
    return base64.urlsafe_b64decode(input.encode('utf-8') + padding)

def get_cognito_public_keys():
    """Fetch and cache public keys from Cognito"""
    global _COGNITO_PUBLIC_KEYS, _KEYS_TIMESTAMP
    
    if (_COGNITO_PUBLIC_KEYS is not None and _KEYS_TIMESTAMP is not None and 
            datetime.utcnow() - _KEYS_TIMESTAMP < KEYS_CACHE_DURATION):
        return _COGNITO_PUBLIC_KEYS
    
    try:
        response = requests.get(COGNITO_JWT_KEYS_URL)
        response.raise_for_status()
        keys = response.json()['keys']
        
        # Convert JWKs to PEM format
        _COGNITO_PUBLIC_KEYS = {
            key['kid']: import_key(key)
            for key in keys
        }
        _KEYS_TIMESTAMP = datetime.utcnow()
        return _COGNITO_PUBLIC_KEYS
    except Exception as e:
        print(f"Error fetching Cognito public keys: {str(e)}")
        if _COGNITO_PUBLIC_KEYS is not None:
            return _COGNITO_PUBLIC_KEYS
        raise

def verify_token(token):
    """Verify the token and return the user_id"""
    try:
        # First try to decode as a custom JWT token
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            return str(payload.get('user_id'))  # Convert to string for consistency
        except jwt.InvalidTokenError:
            # If custom token verification fails, try Cognito token verification
            header = jwt.get_unverified_header(token)
            
            # If there's no kid, it's not a Cognito token
            if 'kid' not in header:
                return None
                
            kid = header['kid']
            public_keys = get_cognito_public_keys()
            public_key = public_keys.get(kid)
            
            if not public_key:
                return None
            
            payload = jwt.decode(
                token,
                public_key,
                algorithms=['RS256'],
                issuer=f'https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}'
            )
            
            return payload.get('sub')
            
    except Exception as e:
        print(f"Token verification error: {str(e)}")
        return None

def authenticate(func):
    """Decorator to authenticate requests using either custom JWT or Cognito tokens"""
    @wraps(func)
    def wrapper(event, context):
        # Extract token from Authorization header
        auth_header = event.get('headers', {}).get('Authorization')
        if not auth_header:
            return {
                'statusCode': 401,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': '*'
                },
                'body': json.dumps({'error': 'No token provided'})
            }

        # Remove 'Bearer ' prefix if present
        token = auth_header.split(' ')[1] if auth_header.startswith('Bearer ') else auth_header
        
        # Verify the token
        user_id = verify_token(token)
        if not user_id:
            return {
                'statusCode': 401,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': '*'
                },
                'body': json.dumps({'error': 'Invalid or expired token'})
            }

        # Add user_id to the event
        event['user_id'] = user_id
        return func(event, context)
    
    return wrapper