# store/utils.py
import os
from django.core.management import call_command
from django.conf import settings
from django.utils import timezone

def create_backup():
    """Create a backup of the database."""
    backup_file = os.path.join(settings.BASE_DIR, f"db_backup_{timezone.now().strftime('%Y%m%d_%H%M%S')}.json")
    with open(backup_file, 'w') as outfile:
        call_command('dumpdata', stdout=outfile)
    return backup_file

def restore_backup(backup_file):
    """Restore the database from a backup file."""
    with open(backup_file, 'r') as infile:
        call_command('loaddata', infile)