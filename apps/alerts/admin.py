from django.contrib import admin
from .models import Notification, SprayAlert

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['title', 'recipient', 'kind', 'unread', 'created_at']

@admin.register(SprayAlert)
class SprayAlertAdmin(admin.ModelAdmin):
    list_display = ['cropper', 'upazila', 'spray_date', 'crop']
