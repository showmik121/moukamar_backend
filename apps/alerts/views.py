from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Notification, SprayAlert
from .serializers import NotificationSerializer, SprayAlertSerializer


class NotificationList(generics.ListAPIView):
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user)


class MarkAllRead(APIView):
    def post(self, request):
        updated = Notification.objects.filter(recipient=request.user, unread=True).update(unread=False)
        return Response({'detail': 'সব সতর্কতা পড়া হয়েছে', 'count': updated})


class SprayAlertListCreate(generics.ListCreateAPIView):
    """কৃষক স্প্রের আগে নোটিশ দিলে ওই উপজেলার খামারিরা জানতে পারেন।"""

    serializer_class = SprayAlertSerializer

    def get_queryset(self):
        qs = SprayAlert.objects.select_related('upazila__district', 'crop', 'cropper')
        user = self.request.user
        # খামারি নিজের উপজেলার নোটিশ দেখেন, কৃষক নিজের দেওয়া নোটিশ
        if user.role == 'farmer' and user.upazila_id:
            return qs.filter(upazila_id=user.upazila_id)
        if user.role == 'cropper':
            return qs.filter(cropper=user)
        return qs

    def perform_create(self, serializer):
        """শুধু নোটিশটা সেভ করে — সতর্কতা তৈরির কাজ Python-এ নেই।

        `sql/08_triggers.sql`-এর `trg_spray_alert_fanout` trigger
        spray_alerts-এ সারি ঢোকার সাথে সাথে ওই উপজেলার সব খামারির জন্য
        notifications বানিয়ে দেয়। আগে এই লুপটা এখানে Python-এ ছিল;
        ডাটাবেজে নেওয়ায় সরাসরি SQL দিয়ে নোটিশ ঢোকালেও খামারিরা জানতে
        পারেন, আর নিয়মটা দুই জায়গায় লেখা থাকে না।
        """
        serializer.save(cropper=self.request.user)
