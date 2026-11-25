from django.contrib import admin
from .models import Notification, SprayAlert


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['title', 'recipient', 'kind', 'unread', 'created_at']
    list_filter = ['kind', 'unread']


@admin.register(SprayAlert)
class SprayAlertAdmin(admin.ModelAdmin):
    list_display = ['cropper', 'upazila', 'crop', 'spray_date', 'chemical']
    list_filter = ['spray_date']
