import os
from django.http import HttpResponse
from django.core.management import call_command
from django.conf import settings
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import render
from django.contrib import messages

@login_required
@user_passes_test(lambda u: u.is_staff)  # Ensure only staff can access
def backup_database(request):
    if request.method == 'POST':
        backup_file = os.path.join(settings.BASE_DIR, 'backup.json')
        try:
            with open(backup_file, 'w') as f:
                call_command('dumpdata', stdout=f)
            messages.success(request, 'Database backup created successfully!')
        except Exception as e:
            messages.error(request, f'Error creating backup: {e}')
    return render(request, 'staff/backup.html')  # Create this template

@login_required
@user_passes_test(lambda u: u.is_staff)  # Ensure only staff can access
def restore_database(request):
    if request.method == 'POST':
        backup_file = os.path.join(settings.BASE_DIR, 'backup.json')
        if os.path.exists(backup_file):
            try:
                call_command('loaddata', backup_file)
                messages.success(request, 'Database restored successfully!')
            except Exception as e:
                messages.error(request, f'Error restoring database: {e}')
        else:
            messages.error(request, 'Backup file does not exist.')
    return render(request, 'staff/restore.html')  # Create this template