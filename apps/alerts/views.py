from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from .models import Notification, SprayAlert
from .serializers import NotificationSerializer, SprayAlertSerializer
from apps.farms.models import Farm

User = get_user_model()


class NotificationList(generics.ListAPIView):
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user)


class MarkAllRead(APIView):
    def post(self, request):
        Notification.objects.filter(recipient=request.user, unread=True).update(unread=False)
        return Response({'detail': 'সব সতর্কতা পড়া হয়েছে'})


class SprayAlertCreate(APIView):
    def post(self, request):
        ser = SprayAlertSerializer(data=request.data)
        if ser.is_valid():
            alert = ser.save(cropper=request.user)
            # ওই উপজেলার সব খামারিকে নোটিফিকেশন দাও
            farmers_in_area = User.objects.filter(
                role='farmer', upazila=alert.upazila, district=alert.district
            )
            notifications = [
                Notification(
                    recipient=farmer,
                    kind='spray',
                    title=f'কীটনাশক স্প্রে — {alert.upazila}',
                    body=f'{alert.spray_date} তারিখে {alert.crop} খেতে স্প্রে হবে (কৃষক: {request.user.name})। বাক্স ঢেকে রাখুন।'
                )
                for farmer in farmers_in_area
            ]
            Notification.objects.bulk_create(notifications)
            return Response(SprayAlertSerializer(alert).data, status=201)
        return Response(ser.errors, status=400)
