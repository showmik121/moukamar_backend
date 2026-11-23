from rest_framework import serializers
from .models import Notification, SprayAlert


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = '__all__'
        read_only_fields = ['recipient', 'unread', 'created_at']


class SprayAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = SprayAlert
        fields = '__all__'
        read_only_fields = ['cropper', 'created_at']
