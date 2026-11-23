from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum
from .models import Farm, Hive, Inspection, Harvest
from .serializers import FarmSerializer, HiveSerializer, InspectionSerializer, HarvestSerializer


class FarmListCreate(generics.ListCreateAPIView):
    serializer_class = FarmSerializer

    def get_queryset(self):
        return Farm.objects.filter(owner=self.request.user)

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class FarmDetail(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = FarmSerializer

    def get_queryset(self):
        return Farm.objects.filter(owner=self.request.user)


class HiveListCreate(generics.ListCreateAPIView):
    serializer_class = HiveSerializer

    def get_queryset(self):
        qs = Hive.objects.filter(farm__owner=self.request.user)
        farm_id = self.request.query_params.get('farm')
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        return qs


class HiveDetail(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = HiveSerializer
    lookup_field = 'code'

    def get_queryset(self):
        return Hive.objects.filter(farm__owner=self.request.user)


class InspectionListCreate(generics.ListCreateAPIView):
    serializer_class = InspectionSerializer

    def get_queryset(self):
        qs = Inspection.objects.filter(hive__farm__owner=self.request.user)
        hive_code = self.request.query_params.get('hive')
        if hive_code:
            qs = qs.filter(hive__code=hive_code)
        return qs.select_related('hive', 'inspector')

    def perform_create(self, serializer):
        inspection = serializer.save(inspector=self.request.user)
        # বাক্সের শেষ পরিদর্শন আপডেট
        hive = inspection.hive
        hive.filled = inspection.frames_filled
        hive.state = inspection.state
        hive.queen = 'আছে' if inspection.queen_seen else 'নেই'
        hive.last_inspection_days = 0
        hive.save()


class HarvestListCreate(generics.ListCreateAPIView):
    serializer_class = HarvestSerializer

    def get_queryset(self):
        return Harvest.objects.filter(hive__farm__owner=self.request.user).select_related('hive')

    def perform_create(self, serializer):
        serializer.save(harvester=self.request.user)


class DashboardView(APIView):
    def get(self, request):
        user = request.user
        farms = Farm.objects.filter(owner=user)
        hives = Hive.objects.filter(farm__in=farms)
        from apps.alerts.models import Notification
        alerts_count = Notification.objects.filter(recipient=user, unread=True).count()

        total_honey = Harvest.objects.filter(hive__farm__in=farms).aggregate(t=Sum('kg'))['t'] or 0

        return Response({
            'farms_total': farms.count(),
            'farms_active': farms.filter(status='সক্রিয়').count(),
            'hives_total': hives.count(),
            'hives_queenless': hives.filter(queen='নেই').count(),
            'honey_this_season': float(total_honey),
            'alerts_unread': alerts_count,
            'overdue_inspections': hives.filter(last_inspection_days__gt=14).count(),
        })
