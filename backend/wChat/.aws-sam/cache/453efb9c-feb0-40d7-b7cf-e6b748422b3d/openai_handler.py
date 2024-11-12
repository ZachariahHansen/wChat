import openai
from datetime import datetime, time

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
        
        Generate a JSON shift schedule that:
        1. Meets all staffing requirements
        2. Respects each person's role and availability
        3. Follows labor laws and break requirements
        4. Distributes shifts fairly
        
        Response format:
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
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are a shift scheduling assistant."},
                {"role": "user", "content": prompt}
            ],
            response_format={ "type": "json_object" }
        )
        
        # Parse and validate the schedule
        schedule = self._parse_schedule(response.choices[0].message.content)
        return self._validate_schedule(schedule, requirements)
    
    def _format_staff_data(self, staff):
        """Format staff data for the AI prompt"""
        formatted = []
        for employee in staff:
            formatted.append(
                f"ID: {employee['id']}\n"
                f"Name: {employee['first_name']} {employee['last_name']}\n"
                f"Role: {employee['role']}\n"
                f"Department: {employee['department']}\n"
                f"Available: {employee['availability']}\n"
            )
        return "\n".join(formatted)
    
    def _parse_schedule(self, ai_response):
        """Parse and structure the AI response"""
        try:
            import json
            schedule = json.loads(ai_response)
            # Add validation and processing here
            return schedule
        except Exception as e:
            raise ValueError(f"Failed to parse AI schedule: {str(e)}")
            
    def _validate_schedule(self, schedule, requirements):
        """Validate the generated schedule meets all requirements"""
        # Add validation logic here
        return schedule

# Example usage in your Lambda function:
def create_ai_schedule(event, context):
    requirements = event['body']['requirements']
    department_id = event['body']['department_id']
    date = event['body']['date']
    
    # Get available staff
    available_staff = get_available_staff(department_id, date)
    
    # Initialize AI planner
    planner = AIShiftPlanner(os.environ['OPENAI_API_KEY'])
    
    # Generate schedule
    schedule = planner.generate_shifts(requirements, available_staff)
    
    # Save to database
    save_schedule(schedule)
    
    return {
        'statusCode': 200,
        'body': json.dumps(schedule)
    }