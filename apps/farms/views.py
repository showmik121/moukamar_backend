from django.shortcuts import get_object_or_404
from rest_framework import generics
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common import call_proc, dict_row, dict_rows, num, split_list

from .models import Farm, Harvest, Hive, HiveEvent, Inspection, Queen
from .serializers import (FarmSerializer, HarvestSerializer, HiveEventSerializer,
                          HiveSerializer, InspectionSerializer, QueenSerializer)


def owned_hive(request, code):
    """বাক্সটা এই ব্যবহারকারীরই কিনা দেখে নেয়।"""
    return get_object_or_404(Hive, code=code, farm__owner=request.user)


def check_owns(request, hive):
    """অন্য কারো বাক্সে এন্ট্রি দেওয়া আটকায়।

    আগে এই যাচাইটা ছিল না — তালিকা দেখার সময় filter হতো, কিন্তু POST-এ
    যেকোনো hive id পাঠিয়ে অন্যের বাক্সে পরিদর্শন বা মধু লেখা যেত।
    """
    if hive.farm.owner_id != request.user.id:
        raise PermissionDenied('এটা আপনার বাক্স নয়')

# "কত দিন পরিদর্শন না হলে বাকি ধরা হবে" — এই নিয়মটা এখন
# sql/05_views.sql-এর v_hive_status ভিউতে (DATEDIFF ... > 14)।
# Python-এ আর আলাদা করে রাখা হয়নি, যাতে দুই জায়গায় দুই নিয়ম না হয়।


class FarmListCreate(generics.ListCreateAPIView):
    serializer_class = FarmSerializer

    def get_queryset(self):
        return (Farm.objects.filter(owner=self.request.user)
                .select_related('upazila__district').prefetch_related('flora', 'hives'))

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class FarmDetail(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = FarmSerializer

    def get_queryset(self):
        return Farm.objects.filter(owner=self.request.user).select_related('upazila__district')


class HiveListCreate(generics.ListCreateAPIView):
    serializer_class = HiveSerializer

    def get_queryset(self):
        qs = (Hive.objects.filter(farm__owner=self.request.user)
              .select_related('farm', 'species')
              .prefetch_related('queens', 'inspections'))
        farm_id = self.request.query_params.get('farm')
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        return qs


class HiveDetail(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = HiveSerializer
    lookup_field = 'code'

    def get_queryset(self):
        return (Hive.objects.filter(farm__owner=self.request.user)
                .select_related('farm', 'species').prefetch_related('queens', 'inspections'))


class HiveEventList(generics.ListCreateAPIView):
    """GET/POST /api/hives/<code>/events/ — বাক্সের ইতিহাস।"""

    serializer_class = HiveEventSerializer

    def get_queryset(self):
        return (HiveEvent.objects.filter(hive__code=self.kwargs['code'],
                                         hive__farm__owner=self.request.user)
                .select_related('actor'))

    def perform_create(self, serializer):
        hive = Hive.objects.get(code=self.kwargs['code'], farm__owner=self.request.user)
        serializer.save(hive=hive, actor=self.request.user)


class QueenListCreate(generics.ListCreateAPIView):
    """নতুন রানী বসানো — `sp_new_queen` procedure ডাকে।

    তিনটে কাজ একসাথে হতে হয়: আগের রানী বন্ধ, নতুন রানী চালু, আর
    রানীহীন বাক্সের অবস্থা বদল। আগে এটা Python-এ ছিল; এখন procedure-এ,
    তাই অ্যাপ ছাড়া সরাসরি SQL দিয়ে করলেও একই নিয়ম মানা হয়।
    """

    serializer_class = QueenSerializer

    def get_queryset(self):
        return Queen.objects.filter(hive__code=self.kwargs['code'],
                                    hive__farm__owner=self.request.user)

    def perform_create(self, serializer):
        hive = owned_hive(self.request, self.kwargs['code'])
        data = serializer.validated_data

        call_proc('CALL sp_new_queen(%s, %s, %s, %s)',
                  [hive.code, data.get('source', ''), data.get('color_mark', ''),
                   self.request.user.id])

        serializer.instance = (Queen.objects
                               .filter(hive=hive, removed_on__isnull=True)
                               .order_by('-installed_on').first())


class InspectionListCreate(generics.ListCreateAPIView):
    serializer_class = InspectionSerializer

    def get_queryset(self):
        qs = (Inspection.objects.filter(hive__farm__owner=self.request.user)
              .select_related('hive', 'inspector'))
        hive_code = self.request.query_params.get('hive')
        if hive_code:
            qs = qs.filter(hive__code=hive_code)
        return qs

    def perform_create(self, serializer):
        """`sp_record_inspection` procedure ডাকে।

        procedure-টা একসাথে করে: পরিদর্শন লেখা, রোগের কোডগুলো junction-এ
        বসানো (অচেনা কোড SAVEPOINT দিয়ে বাদ), বাক্সের অবস্থা হালনাগাদ,
        আর ইতিহাসে ঘটনা লেখা। আগে এই চারটে কাজ Python-এ ছিল।
        """
        data = serializer.validated_data
        hive = data['hive']
        check_owns(self.request, hive)

        codes = ','.join(data.get('disease_codes') or [])

        out = call_proc(
            'CALL sp_record_inspection(%s, %s, %s, %s, %s, %s, %s, %s, @insp, @added)',
            [hive.code, data['inspect_date'], data['frames_filled'], data['state'],
             data['queen_seen'], data['eggs_seen'], codes, self.request.user.id],
            ['insp', 'added'])

        serializer.instance = Inspection.objects.get(pk=out['insp'])


class HarvestListCreate(generics.ListCreateAPIView):
    serializer_class = HarvestSerializer

    def get_queryset(self):
        qs = (Harvest.objects.filter(hive__farm__owner=self.request.user)
              .select_related('hive', 'flora', 'harvester'))
        hive_code = self.request.query_params.get('hive')
        if hive_code:
            qs = qs.filter(hive__code=hive_code)
        return qs

    def perform_create(self, serializer):
        """`sp_add_harvest` procedure ডাকে।

        আর্দ্রতা, পরিমাণ আর তারিখের যাচাই procedure-এর ভেতরে — ভুল হলে
        বাংলা বার্তা আসে। ডাটাবেজের CHECK constraint শেষ রক্ষাকবচ
        হিসেবে পেছনে থাকে।
        """
        data = serializer.validated_data
        hive = data['hive']
        check_owns(self.request, hive)

        flora = data.get('flora')
        out = call_proc(
            'CALL sp_add_harvest(%s, %s, %s, %s, %s, %s, @hid)',
            [hive.code, data['harvest_date'], data['kg'], data.get('moisture'),
             flora.name if flora else None, self.request.user.id],
            ['hid'])

        serializer.instance = Harvest.objects.get(pk=out['hid'])


# =====================================================================
# রিপোর্টের endpoint — এগুলো ORM ব্যবহার করে না, ভিউ থেকে পড়ে
# =====================================================================
# CRUD-এর জন্য ORM ভালো (যাচাই, serializer, অনুমতি)। কিন্তু হিসাব করা
# সংখ্যার জন্য ভিউ ভালো: পুরো হিসাবটা এক জায়গায় থাকে, আর অ্যাপ ও
# সরাসরি SQL দুই দিক থেকেই একই উত্তর আসে।

class DashboardView(APIView):
    """GET /api/dashboard/ — এক অনুরোধে হোমের সব সংখ্যা।

    আগে এখানে Python-এ লুপ চালিয়ে "বাকি পরিদর্শন" গোনা হতো (প্রতিটা
    বাক্সের পরিদর্শন টেনে এনে)। এখন পুরোটা `v_farmer_dashboard`
    ভিউয়ের একটা সারি — ভিউটা নিজে আবার `v_hive_status`-এর উপর বসানো।
    """

    def get(self, request):
        row = dict_row('SELECT * FROM v_farmer_dashboard WHERE owner_id = %s',
                       [request.user.id])

        if row is None:
            # কৃষক বা অ্যাডমিন — ভিউতে শুধু খামারি আছে
            return Response({
                'farms_total': 0, 'farms_active': 0, 'hives_total': 0,
                'hives_queenless': 0, 'honey_this_season': 0,
                'alerts_unread': 0, 'overdue_inspections': 0,
            })

        return Response({
            'farms_total': num(row['farms_total']),
            'farms_active': num(row['farms_active']),
            'hives_total': num(row['hives_total']),
            'hives_queenless': num(row['hives_queenless']),
            'honey_this_season': num(row['honey_total_kg']),
            'alerts_unread': num(row['alerts_unread']),
            'overdue_inspections': num(row['overdue_inspections']),
        })


class FarmHiveSummary(APIView):
    """GET /api/farms/summary/ — খামার অনুযায়ী বাক্সের সারাংশ (hives.html)।

    `v_farm_summary` ভিউ থেকে — বাক্স গোনা, সবল/দুর্বল/রানীহীন ভাগ,
    মোট মধু আর ফুলের তালিকা সব একসাথে।
    """

    def get(self, request):
        rows = dict_rows("""
            SELECT * FROM v_farm_summary
             WHERE owner_id = %s
             ORDER BY farm_name
        """, [request.user.id])

        return Response([{
            'id': r['farm_id'],
            'name': r['farm_name'],
            'status': r['status'],
            'type': r['farm_type'],
            'district': r['district'],
            'upazila': r['upazila'],
            'lat': num(r['lat'], None),
            'lng': num(r['lng'], None),
            'flora': split_list(r['flora']),
            'hive_count': num(r['hive_count']),
            'strong': num(r['strong_count']),
            'weak': num(r['weak_count']),
            'queenless': num(r['queenless_count']),
            'filled_frames': num(r['filled_frames']),
            'honey_kg': num(r['total_honey_kg']),
        } for r in rows])


class HiveStatusView(APIView):
    """GET /api/hives/status/?farm=&overdue=1 — বাক্সের চলতি অবস্থা।

    `v_hive_status` ভিউ থেকে এক query-তে: রানী আছে কিনা, রানীর বয়স,
    শেষ পরিদর্শনের কত দিন হলো, পরিদর্শন বাকি কিনা, মোট মধু।

    `overdue=1` দিলে `v_overdue_hives` থেকে পড়া হয় — ওটা এই ভিউয়ের
    উপরেই বসানো আরেকটা ভিউ।
    """

    def get(self, request):
        source = 'v_overdue_hives' if request.query_params.get('overdue') == '1' else 'v_hive_status'
        sql = f'SELECT * FROM {source} WHERE owner_id = %s'
        params = [request.user.id]

        farm_id = request.query_params.get('farm')
        if farm_id:
            sql += ' AND farm_id = %s'
            params.append(farm_id)

        sql += ' ORDER BY code'

        return Response([{
            'code': r['code'],
            'farm': r['farm_id'],
            'farm_name': r['farm_name'],
            'species': r['species'],
            'frames': num(r['frames']),
            'filled': num(r['filled']),
            'state': r['state'],
            'queen': r['queen'],
            'queenAge': num(r['queen_age']),
            'queen_source': r['queen_source'] or '',
            'queen_color': r['queen_color'] or '',
            'last_inspection': r['last_inspection'],
            'last': num(r['days_since_inspection'], None),
            'overdue': bool(r['inspection_overdue']),
            'honey_kg': num(r['total_honey_kg']),
            'last_harvest': r['last_harvest'],
        } for r in dict_rows(sql, params)])


class MonthlyHoneyView(APIView):
    """GET /api/reports/monthly-honey/ — মাসভিত্তিক মধু (dashboard.html-এর চার্ট)।

    `v_monthly_honey` ভিউ থেকে — বাংলা মাসের নাম months টেবিল থেকেই আসে।
    """

    def get(self, request):
        rows = dict_rows("""
            SELECT * FROM v_monthly_honey
             WHERE owner_id = %s
             ORDER BY yr, mn
        """, [request.user.id])

        return Response([{
            'year': num(r['yr']),
            'month': num(r['mn']),
            'month_name': r['month_name'],
            'harvests': num(r['harvest_count']),
            'hives': num(r['hive_count']),
            'total_kg': num(r['total_kg']),
            'avg_kg': num(r['avg_kg']),
            'avg_moisture': num(r['avg_moisture'], None),
        } for r in rows])


class MoveHiveView(APIView):
    """POST /api/hives/<code>/move/ — বাক্স অন্য খামারে সরানো।

    hive.html-এর "অন্য খামারে সরান" বোতামের জন্য। পুরো কাজটা
    `sp_move_hive` procedure করে — খামার বদল আর ইতিহাসে ঘটনা লেখা
    একটা transaction-এ, আর যাচাইগুলো (বাক্স আছে কিনা, খামার আছে কিনা,
    অন্য খামারির খামার নয় কিনা) procedure-এর ভেতরে।
    """

    def post(self, request, code):
        hive = owned_hive(request, code)
        target = request.data.get('farm') or request.data.get('target_farm')

        if not target:
            return Response({'detail': 'কোন খামারে সরাবেন সেটা দিন'}, status=400)

        call_proc('CALL sp_move_hive(%s, %s, %s)',
                  [hive.code, target, request.user.id])

        row = dict_row('SELECT * FROM v_hive_status WHERE code = %s', [hive.code])
        return Response({
            'code': row['code'],
            'farm': row['farm_id'],
            'farm_name': row['farm_name'],
            'detail': 'বাক্স সরানো হয়েছে',
        })


class RemindOverdueView(APIView):
    """POST /api/hives/remind-overdue/ — বাকি পরিদর্শনের সতর্কতা পাঠানো।

    `sp_notify_overdue_inspections` procedure CURSOR দিয়ে
    `v_overdue_hives` ভিউয়ের প্রতিটা সারি ধরে একটা করে notification লেখে।
    """

    def post(self, request):
        out = call_proc('CALL sp_notify_overdue_inspections(%s, @sent)',
                        [request.user.id], ['sent'])
        sent = num(out['sent'])
        return Response({
            'sent': sent,
            'detail': (f'{sent}টা বাক্সের জন্য সতর্কতা পাঠানো হয়েছে'
                       if sent else 'কোনো বাক্সের পরিদর্শন বাকি নেই'),
        })


class SeasonReportView(APIView):
    """GET /api/reports/season/?year=2026 — মৌসুমের হিসাব।

    `sp_season_report` procedure-এর ৬টা OUT প্যারামিটার থেকে। FUNCTION
    একটাই মান দিতে পারে, procedure কয়েকটা — এখানে সেটার দরকার পড়েছে।
    """

    def get(self, request):
        from django.utils import timezone

        try:
            year = int(request.query_params.get('year') or timezone.localdate().year)
        except ValueError:
            return Response({'detail': 'বছরটা সংখ্যায় দিন'}, status=400)

        out = call_proc(
            'CALL sp_season_report(%s, %s, @total, @cnt, @hives, @best, @best_kg, @moisture)',
            [request.user.id, year],
            ['total', 'cnt', 'hives', 'best', 'best_kg', 'moisture'])

        return Response({
            'year': year,
            'total_kg': num(out['total']),
            'harvest_count': num(out['cnt']),
            'hive_count': num(out['hives']),
            'best_hive': out['best'],
            'best_hive_kg': num(out['best_kg']),
            'avg_moisture': num(out['moisture'], None),
        })
