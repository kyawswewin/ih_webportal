import os
import subprocess
from django.conf import settings
from django.core.management import call_command
from django.core.files.storage import default_storage

def backup_database(backup_file_name='db_backup.json'):
    backup_file_path = os.path.join(settings.BASE_DIR, backup_file_name)
    
    try:
        # Use the dumpdata command to create a backup
        with open(backup_file_path, 'w') as backup_file:
            call_command('dumpdata', stdout=backup_file)
        return backup_file_path
    except Exception as e:
        print(f"Error creating backup: {e}")
        return None