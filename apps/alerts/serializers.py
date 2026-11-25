from rest_framework import serializers

from apps.locations.utils import resolve_upazila
from apps.reference.models import Crop

from .models import Notification, SprayAlert


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'kind', 'title', 'body', 'ref_table', 'ref_id', 'unread', 'created_at']


class SprayAlertSerializer(serializers.ModelSerializer):
    """কৃষকের স্প্রে নোটিশ।

    frontend জেলা, উপজেলা আর ফসলের নাম পাঠায় — এখানে সেগুলো
    locations ও crops টেবিলের সারিতে রূপান্তর হয়।
    """

    district = serializers.CharField(write_only=True, required=False, allow_blank=True, default='')
    upazila = serializers.CharField(write_only=True, required=False, allow_blank=True, default='')
    crop = serializers.CharField(write_only=True, required=False, allow_blank=True, default='')

    upazila_name = serializers.CharField(source='upazila.name', read_only=True)
    district_name = serializers.CharField(source='upazila.district.name', read_only=True)
    crop_name = serializers.CharField(source='crop.name', read_only=True)
    cropper_name = serializers.CharField(source='cropper.name', read_only=True)

    class Meta:
        model = SprayAlert
        fields = ['id', 'district', 'upazila', 'crop', 'spray_date', 'spray_time',
                  'chemical', 'notes', 'created_at',
                  'upazila_name', 'district_name', 'crop_name', 'cropper_name']
        read_only_fields = ['created_at']

    def validate(self, data):
        upazila = resolve_upazila(data.pop('district', ''), data.pop('upazila', ''))
        if not upazila:
            raise serializers.ValidationError({'district': 'জেলা ও উপজেলা দিন'})
        data['upazila'] = upazila

        crop_name = (data.pop('crop', '') or '').strip()
        if not crop_name:
            raise serializers.ValidationError({'crop': 'কোন ফসলে স্প্রে হবে লিখুন'})
        data['crop'] = Crop.objects.get_or_create(name=crop_name)[0]
        return data
