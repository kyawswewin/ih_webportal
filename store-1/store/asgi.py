import os
import subprocess
from django.http import HttpResponse
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.shortcuts import render
from django.core.files.storage import FileSystemStorage
from django.utils import timezone

@login_required
def backup_database(request):
    if request.method == 'POST':
        # Define the backup file name and path
        backup_file_name = f"db_backup_{timezone.now().strftime('%Y%m%d_%H%M%S')}.json"
        backup_file_path = os.path.join(settings.MEDIA_ROOT, backup_file_name)

        # Run the dumpdata command to create a backup
        try:
            subprocess.run(['python', 'manage.py', 'dumpdata', '--output', backup_file_path, '--indent', '4'], check=True)
            return HttpResponse(f"Backup created successfully: {backup_file_name}")
        except subprocess.CalledProcessError as e:
            return HttpResponse(f"Error creating backup: {str(e)}", status=500)

    return render(request, 'backup.html')

@login_required
def restore_database(request):
    if request.method == 'POST' and request.FILES['backup_file']:
        backup_file = request.FILES['backup_file']
        fs = FileSystemStorage()
        filename = fs.save(backup_file.name, backup_file)
        backup_file_path = os.path.join(settings.MEDIA_ROOT, filename)

        # Run the loaddata command to restore the backup
        try:
            subprocess.run(['python', 'manage.py', 'loaddata', backup_file_path], check=True)
            return HttpResponse("Database restored successfully.")
        except subprocess.CalledProcessError as e:
            return HttpResponse(f"Error restoring database: {str(e)}", status=500)

    return render(request, 'restore.html')