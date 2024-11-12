import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

class NotificationService:
    def __init__(self):
        self.DB_HOST = os.environ['DB_HOST']
        self.DB_USER = os.environ['POSTGRES_USER']
        self.DB_PASSWORD = os.environ['POSTGRES_PASSWORD']

    def get_db_connection(self):
        return psycopg2.connect(
            host=self.DB_HOST,
            user=self.DB_USER,
            password=self.DB_PASSWORD
        )

    def create_notification(self, user_id, content):
        # Create single notification
        conn = self.get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO notification (user_id, content, time_stamp)
                    VALUES (%s, %s, CURRENT_TIMESTAMP)
                    RETURNING id
                """, (user_id, content))
                notification_id = cur.fetchone()['id']
                conn.commit()
                return notification_id
        finally:
            conn.close()

    def create_notifications_batch(self, notifications):
        # Create multiple notifications
        conn = self.get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.executemany("""
                    INSERT INTO notification (user_id, content, time_stamp)
                    VALUES (%s, %s, CURRENT_TIMESTAMP)
                """, [(n['user_id'], n['content']) for n in notifications])
                conn.commit()
        finally:
            conn.close()

    def notify_managers(self, content):
        # Notify all managers
        conn = self.get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO notification (user_id, content, time_stamp)
                    SELECT id, %s, CURRENT_TIMESTAMP
                    FROM "user"
                    WHERE is_manager = true
                """, (content,))
                conn.commit()
        finally:
            conn.close()

    def notify_department(self, department_id, content):
        # Notify all users in a department
        conn = self.get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO notification (user_id, content, time_stamp)
                    SELECT user_id, %s, CURRENT_TIMESTAMP
                    FROM department_group
                    WHERE department_id = %s
                """, (content, department_id))
                conn.commit()
        finally:
            conn.close()

def availability_change_template():
    # John Smith has updated their availability:
    # - Tuesday: Available 09:00 to 17:00
    # - Wednesday: Not available
    return

def time_off_request_template():
    # New time off request from John Smith ({start_date} to {end_date})"
    # or
    # New time off request from John Smith ({date})
    return

def time_off_response_template():
    # Your time off request for {start_date} to {end_date} has been {status}
    # or
    # Your time off request for {date} has been {status}
    return

def department_change_template():
    # You have been added to the {department} department
    # or
    # You have been removed from the {department} department
    return

def new_message_template():
    # New message from {sender}: {preview}
    return

def role_change_template():
    # Your role has been updated to {role}
    return

def new_shift_template():
    # New shift assigned: {date} from {start_time} to {end_time}
    return

def shift_change_template():
    # Your shift on {date} has been {action}
    return

def shift_available_template():
    # A new shift is available: {date} from {start_time} to {end_time}
    # or
    # New shifts are available
    return

