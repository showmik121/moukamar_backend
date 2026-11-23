from rest_framework import generics
from rest_framework.permissions import AllowAny
from .models import Disease, Flora, Outbreak
from .serializers import DiseaseSerializer, FloraSerializer, OutbreakSerializer
from apps.accounts.models import User
from apps.accounts.serializers import UserSerializer
from apps.farms.models import Farm, Hive
from rest_framework.response import Response
from rest_framework.views import APIView


class DiseaseList(generics.ListAPIView):
    queryset = Disease.objects.all()
    serializer_class = DiseaseSerializer
    permission_classes = [AllowAny]


class FloraList(generics.ListAPIView):
    queryset = Flora.objects.all()
    serializer_class = FloraSerializer
    permission_classes = [AllowAny]


class OutbreakList(generics.ListAPIView):
    queryset = Outbreak.objects.all()
    serializer_class = OutbreakSerializer
    permission_classes = [AllowAny]


class FarmerList(generics.ListAPIView):
    serializer_class = UserSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        qs = User.objects.filter(role='farmer', is_active=True)
        district = self.request.query_params.get('district')
        upazila = self.request.query_params.get('upazila')
        if district:
            qs = qs.filter(district=district)
        if upazila:
            qs = qs.filter(upazila=upazila)
        return qs


class MapDataView(APIView):
    """
    ডাটাবেসের সকল রেজিস্টার্ড খামারি ও তাদের খামারের তথ্য ম্যাপের জন্য প্রদান করে
    """
    permission_classes = [AllowAny]

    def get(self, request):
        farmers = User.objects.filter(role='farmer', is_active=True)
        results = []
        for u in farmers:
            # ইউজারের খামার ও বাক্সের হিসাব
            user_farms = Farm.objects.filter(owner=u)
            hives_count = Hive.objects.filter(farm__in=user_farms).count()
            
            # খামারের অবস্থান (যদি খামার এ থাকে) অন্যথায় ইউজারের জেলা/উপজেলা
            lat = None
            lng = None
            farm_name = u.farm_name or f"{u.name}-এর খামার"
            if user_farms.exists():
                first_farm = user_farms.first()
                if first_farm.lat and first_farm.lng:
                    lat = float(first_farm.lat)
                    lng = float(first_farm.lng)
                farm_name = first_farm.name

            results.append({
                'id': u.id,
                'name': u.name,
                'phone': u.phone,
                'farm': farm_name,
                'district': u.district,
                'upazila': u.upazila,
                'type': u.farm_type or 'স্থায়ী',
                'hives': hives_count,
                'flora': ['সরিষা', 'মিশ্র ফুল'],
                'exp': u.experience or 1,
                'lat': lat,
                'lng': lng,
                'honeyProduced': 0,
                'activeBoxes': hives_count,
                'rating': 5.0,
                'regDate': u.created_at.strftime('%d %B %Y') if u.created_at else 'আজ'
            })
        return Response(results)
