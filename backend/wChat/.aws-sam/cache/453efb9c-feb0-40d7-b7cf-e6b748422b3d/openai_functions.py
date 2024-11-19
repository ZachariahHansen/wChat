import json
import os
import openai
import psycopg2
from psycopg2.extras import RealDictCursor
from functions.auth_layer.auth import authenticate
from datetime import datetime, time


# Database connection parameters
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['POSTGRES_USER']
DB_PASSWORD = os.environ['POSTGRES_PASSWORD']
OPENAI_API_KEY = os.environ['OPENAI_API_KEY']

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD
    )

def get_available_staff(cur, department_id, date):
    """Get available staff for the given department and date"""
    cur.execute("""
        SELECT 
            u.id,
            u.first_name,
            u.last_name,
            r.name as role,
            d.name as department,
            array_agg(
                json_build_object(
                    'day', a.day,
                    'start_time', a.start_time,
                    'end_time', a.end_time,
                    'is_available', a.is_available
                )
            ) as availability
        FROM "user" u
        JOIN role r ON u.role_id = r.id
        JOIN department_group dg ON u.id = dg.user_id
        JOIN department d ON dg.department_id = d.id
        LEFT JOIN availability a ON u.id = a.user_id
        WHERE dg.department_id = %s
        AND NOT EXISTS (
            SELECT 1 FROM time_off_request tor
            WHERE tor.user_id = u.id
            AND %s BETWEEN tor.start_date AND tor.end_date
            AND tor.status = 'approved'
        )
        GROUP BY u.id, u.first_name, u.last_name, r.name, d.name
    """, (department_id, date))
    
    return cur.fetchall()

@authenticate
def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return response(200, 'OK')
    
    if event['httpMethod'] != 'POST':
        return response(405, {'error': 'Method not allowed'})
    
    try:
        body = json.loads(event['body'])
        requirements = body.get('requirements')
        department_id = body.get('department_id')
        date = body.get('date')
        
        # Get the user ID from the event context
        user_id = None
        try:
            # Try different possible locations of user ID
            if 'requestContext' in event and 'authorizer' in event['requestContext']:
                user_id = event['requestContext']['authorizer'].get('userId')
            elif 'requestContext' in event and 'identity' in event['requestContext']:
                user_id = event['requestContext']['identity'].get('userId')
            elif 'userId' in body:
                # Fallback to user ID in request body if provided
                user_id = body.get('userId')
            
            if not user_id:
                print("Warning: No user ID found in request context")
                # You might want to handle this case differently based on your requirements
                user_id = 1  # Default user ID for testing - replace with appropriate handling
                
        except Exception as e:
            print(f"Error getting user ID: {str(e)}")
            user_id = 1  # Default user ID for testing - replace with appropriate handling
        
        if not all([requirements, department_id, date]):
            return response(400, {'error': 'Missing required fields'})
        
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get available staff
                available_staff = get_available_staff(cur, department_id, date)
                
                if not available_staff:
                    return response(400, {'error': 'No available staff found for the specified department and date'})
                
                # Print available staff for debugging
                print(f"Available staff: {json.dumps(available_staff, default=str)}")
                
                # Initialize AI planner
                planner = AIShiftPlanner(OPENAI_API_KEY)
                
                # Generate schedule
                schedule = planner.generate_shifts(requirements, available_staff)
                
                # Save generated shifts to database
                saved_shifts = []
                for shift in schedule['shifts']:
                    try:
                        cur.execute("""
                            INSERT INTO shift (
                                start_time,
                                end_time,
                                scheduled_by_id,
                                department_id,
                                user_id,
                                status
                            ) VALUES (%s, %s, %s, %s, %s, 'scheduled')
                            RETURNING id
                        """, (
                            f"{date} {shift['start_time']}",
                            f"{date} {shift['end_time']}",
                            user_id,  # Use the retrieved user_id
                            department_id,
                            shift['assigned_staff'][0]
                        ))
                        
                        shift_id = cur.fetchone()['id']
                        saved_shifts.append(shift_id)
                        
                    except Exception as e:
                        print(f"Error saving shift: {str(e)}")
                        # Continue with other shifts even if one fails
                        continue
                
                if not saved_shifts:
                    conn.rollback()
                    return response(500, {'error': 'Failed to save any shifts'})
                
                conn.commit()
                schedule['saved_shift_ids'] = saved_shifts
                return response(200, schedule)
                
        finally:
            conn.close()
            
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': 'Internal server error', 'details': str(e)})

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

class AIShiftPlanner:
    def __init__(self, api_key):
        self.client = openai.Client(api_key=api_key)
        
    def generate_shifts(self, requirements, available_staff):
        """
        Generate shift assignments based on natural language requirements
        
        Args:
            requirements (str): Natural language description of shift requirements
            available_staff (list): List of staff dictionaries with availability info
        """
        # Format staff data for the AI
        staff_context = self._format_staff_data(available_staff)
        
        # Construct the prompt
        prompt = f"""
        Given these shift requirements: "{requirements}"
        
        And these available staff members:
        {staff_context}
        
        Generate a shift schedule that:
        1. Meets all staffing requirements
        2. Respects each person's role and availability
        3. Follows labor laws and break requirements
        4. Distributes shifts fairly
        
        You must respond with ONLY a JSON object in this exact format, with no additional text or explanation:
        {{
            "shifts": [
                {{
                    "start_time": "HH:MM",
                    "end_time": "HH:MM",
                    "assigned_staff": ["staff_id"],
                    "role": "role_name"
                }}
            ]
        }}
        """
        
        # Get AI response
        response = self.client.chat.completions.create(
            model="gpt-4-1106-preview",  # or "gpt-3.5-turbo-1106"
            messages=[
                {
                    "role": "system", 
                    "content": "You are a shift scheduling assistant. You must respond only with valid JSON objects, no additional text."
                },
                {
                    "role": "user", 
                    "content": prompt
                }
            ],
            temperature=0.7,  # Add some variation in scheduling
            max_tokens=2000   # Ensure enough tokens for response
        )
        
        # Parse and validate the schedule
        schedule = self._parse_schedule(response.choices[0].message.content)
        return self._validate_schedule(schedule, requirements)
    
    def _format_staff_data(self, staff):
        """Format staff data for the AI prompt"""
        formatted = []
        for employee in staff:
            availability_str = "\n".join(
                f"- {avail['day']}: {'Available' if avail['is_available'] else 'Unavailable'} "
                f"{avail['start_time']} to {avail['end_time']}"
                for avail in employee['availability']
            )
            
            formatted.append(
                f"Staff Member:\n"
                f"ID: {employee['id']}\n"
                f"Name: {employee['first_name']} {employee['last_name']}\n"
                f"Role: {employee['role']}\n"
                f"Department: {employee['department']}\n"
                f"Availability:\n{availability_str}\n"
            )
        return "\n".join(formatted)
    
    def _parse_schedule(self, ai_response):
        """Parse and structure the AI response"""
        try:
            # Clean the response if it contains any markdown formatting
            cleaned_response = ai_response.strip('`').strip()
            if cleaned_response.startswith('json'):
                cleaned_response = cleaned_response[4:].strip()
                
            schedule = json.loads(cleaned_response)
            return schedule
        except Exception as e:
            print(f"Failed to parse AI response: {ai_response}")
            raise ValueError(f"Failed to parse AI schedule: {str(e)}")
            
    def _validate_schedule(self, schedule, requirements):
        """Validate the generated schedule meets all requirements"""
        # Basic validation
        if not isinstance(schedule, dict) or 'shifts' not in schedule:
            raise ValueError("Invalid schedule format")
            
        for shift in schedule['shifts']:
            if not all(key in shift for key in ['start_time', 'end_time', 'assigned_staff', 'role']):
                raise ValueError("Invalid shift format")
                
            # Validate time format
            for time_field in ['start_time', 'end_time']:
                try:
                    # Check if time is in HH:MM format
                    hours, minutes = shift[time_field].split(':')
                    if not (0 <= int(hours) <= 23 and 0 <= int(minutes) <= 59):
                        raise ValueError
                except:
                    raise ValueError(f"Invalid time format in {time_field}: {shift[time_field]}")
                    
            # Validate assigned_staff is a non-empty list
            if not isinstance(shift['assigned_staff'], list) or not shift['assigned_staff']:
                raise ValueError("assigned_staff must be a non-empty list")
                
        return schedule