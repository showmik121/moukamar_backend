from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common import bn_date, dict_rows, num, split_list

from .models import BeeSpecies, Crop, Disease, Flora, Month, Symptom
from .serializers import (BeeSpeciesSerializer, CropSerializer, DiseaseSerializer,
                          FloraSerializer, MonthSerializer, SymptomSerializer)


class DiseaseList(generics.ListAPIView):
    """GET /api/diseases/ — ৮টা রোগ, লক্ষণ ও ধাপ সহ।

    prefetch_related ছাড়া প্রতিটা রোগের জন্য আলাদা query যেত (N+1)।
    """

    serializer_class = DiseaseSerializer
    permission_classes = [AllowAny]
    queryset = Disease.objects.prefetch_related('symptoms', 'steps')


class SymptomList(APIView):
    """GET /api/symptoms/ — frontend-এর SYMPTOMS-এর মতো {কোড: নাম}।"""

    permission_classes = [AllowAny]

    def get(self, request):
        return Response({s.code: s.name for s in Symptom.objects.all()})


class FloraList(generics.ListAPIView):
    serializer_class = FloraSerializer
    permission_classes = [AllowAny]
    queryset = Flora.objects.prefetch_related('blooms')


class MonthList(generics.ListAPIView):
    serializer_class = MonthSerializer
    permission_classes = [AllowAny]
    queryset = Month.objects.all()


class CropList(generics.ListAPIView):
    serializer_class = CropSerializer
    permission_classes = [AllowAny]
    queryset = Crop.objects.all()


class BeeSpeciesList(generics.ListAPIView):
    serializer_class = BeeSpeciesSerializer
    permission_classes = [AllowAny]
    queryset = BeeSpecies.objects.all()


class DiseaseSymptomMatrix(APIView):
    """GET /api/disease-symptoms/ — রোগ ও তার লক্ষণ এক সারিতে।

    `v_disease_symptoms` ভিউ থেকে — M:N junction-এর GROUP_CONCAT করা রূপ।
    """

    permission_classes = [AllowAny]

    def get(self, request):
        rows = dict_rows('SELECT * FROM v_disease_symptoms ORDER BY risk, disease')
        return Response([{
            'code': r['disease_code'],
            'disease': r['disease'],
            'kind': r['kind'],
            'risk': r['risk'],
            'symptom_count': r['symptom_count'],
            'symptoms': split_list(r['symptom_codes']),
            'symptom_names': [s.strip() for s in (r['symptom_names'] or '').split('·') if s.strip()],
            'treat_steps': r['treat_steps'],
            'prevent_steps': r['prevent_steps'],
        } for r in rows])


class OutbreakList(APIView):
    """GET /api/outbreaks/ — গত ৩০ দিনে এলাকার রোগ (alerts.html)।

    `v_area_outbreaks` ভিউ রোগ ও উপজেলা ধরে আলাদা সারি দেয়। frontend
    এক রোগের সব এলাকা একসাথে চায়, তাই ভিউয়ের উপরেই আরেকবার GROUP BY।
    """

    permission_classes = [AllowAny]

    SQL = """
        SELECT disease,
               risk,
               GROUP_CONCAT(DISTINCT upazila ORDER BY upazila SEPARATOR ', ') AS places,
               SUM(farms_affected) AS farms,
               MAX(hives_affected) AS hives,
               MAX(last_seen)      AS last_seen,
               MAX(alert)          AS alert
          FROM v_area_outbreaks
         GROUP BY disease, risk
         ORDER BY farms DESC, disease
    """

    def get(self, request):
        return Response([{
            'disease': r['disease'],
            'risk': r['risk'],
            'where': r['places'] or '—',
            'farms': num(r['farms']),
            'hives': num(r['hives']),
            'last_seen': r['last_seen'],
            'alert': bool(r['alert']),
        } for r in dict_rows(self.SQL)])


class FarmerList(APIView):
    """GET /api/farmers/?district=&upazila=&flora= — খামারি তালিকা।

    পুরো জোড়া লাগানোর কাজটা `v_farmer_directory` ভিউ করে — বাক্স গোনা,
    মোট মধু, ফুলের তালিকা, অবস্থান (খামারের না থাকলে জেলার)। আগে এটা
    Python-এ কয়েকটা query করে করা হতো।
    """

    permission_classes = [AllowAny]

    def get(self, request):
        sql = 'SELECT * FROM v_farmer_directory WHERE 1 = 1'
        params = []

        district = request.query_params.get('district')
        upazila = request.query_params.get('upazila')
        flora = request.query_params.get('flora')

        if district:
            sql += ' AND district = %s'
            params.append(district)
        if upazila:
            sql += ' AND upazila = %s'
            params.append(upazila)
        if flora:
            # EXISTS — ভিউয়ের comma-জোড়া লেখায় LIKE করার চেয়ে নির্ভরযোগ্য
            sql += """ AND EXISTS (
                           SELECT 1
                             FROM farm_flora ff
                             JOIN flora fl ON fl.id = ff.flora_id
                             JOIN farms f  ON f.id = ff.farm_id
                            WHERE f.owner_id = v_farmer_directory.user_id
                              AND fl.name = %s)"""
            params.append(flora)

        sql += ' ORDER BY name'
        return Response([self.shape(r) for r in dict_rows(sql, params)])

    @staticmethod
    def shape(r):
        """ভিউয়ের কলামের নাম → frontend যে নামগুলো চেনে।"""
        return {
            'id': r['user_id'],
            'name': r['name'],
            'phone': r['phone'],
            'farm': r['farm_name'],
            'district': r['district'] or '',
            'upazila': r['upazila'] or '',
            'lat': num(r['lat'], None),
            'lng': num(r['lng'], None),
            'type': r['farm_type'],
            'hives': num(r['hive_count']),
            'activeBoxes': num(r['active_hives']),
            'honeyProduced': num(r['total_honey_kg']),
            'flora': split_list(r['flora']),
            'exp': num(r['experience_years']),
            'rating': num(r['rating']),
            'regDate': bn_date(r['created_at']),
        }


class MapDataView(FarmerList):
    """GET /api/map-farmers/ — ম্যাপের জন্য একই তথ্য।

    আগে এই view-তে flora, rating আর honeyProduced কোডে বসানো ছিল
    (সবার জন্য একই) — এখন ভিউ থেকে আসল হিসাব আসে।
    """
