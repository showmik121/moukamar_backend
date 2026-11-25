"""মৌখামার backend-এর API পুরো পথ ধরে যাচাই।

Django-র নিজের test Client ব্যবহার করে — সার্ভার চালু করার দরকার নেই,
কিন্তু URL, serializer, view আর ডাটাবেজ সবই আসলভাবে চলে।

চালানো (backend ফোল্ডার থেকে):
    .venv\\Scripts\\python.exe <এই ফাইলের পথ>
"""

import os
import sys

sys.path.insert(0, os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'moukhamar.settings')

import django  # noqa: E402

django.setup()

from django.test import Client  # noqa: E402

from apps.accounts.models import User  # noqa: E402
from apps.alerts.models import Notification, SprayAlert  # noqa: E402
from apps.farms.models import Farm  # noqa: E402
from apps.farms.models import Inspection as InspectionModel  # noqa: E402
from apps.trust.models import AuditLog  # noqa: E402

PASS, FAIL = [], []


def check(label, condition, detail=''):
    (PASS if condition else FAIL).append(label)
    mark = 'OK  ' if condition else 'FAIL'
    line = f'[{mark}] {label}'
    if detail:
        line += f'  →  {detail}'
    print(line)


c = Client()

# ---------- ১. খোলা (AllowAny) endpoint ----------
r = c.get('/api/diseases/')
diseases = r.json() if r.status_code == 200 else []
check('GET /api/diseases/', r.status_code == 200 and len(diseases) == 8,
      f'status={r.status_code} count={len(diseases)}')

if diseases:
    d = next((x for x in diseases if x['id'] == 'varroa'), diseases[0])
    check('রোগের লক্ষণ junction থেকে আসছে', len(d['symptoms']) == 3, f"symptoms={d['symptoms']}")
    check('signs/prevent/treat ধাপ টেবিল থেকে আসছে',
          len(d['signs']) == 3 and len(d['prevent']) == 3 and len(d['treat']) == 3,
          f"signs={len(d['signs'])} prevent={len(d['prevent'])} treat={len(d['treat'])}")
    check('ধাপের ক্রম ঠিক আছে', d['signs'][0].startswith('মৌমাছির ডানা'), d['signs'][0])

r = c.get('/api/symptoms/')
symptoms = r.json() if r.status_code == 200 else {}
check('GET /api/symptoms/', r.status_code == 200 and len(symptoms) == 10,
      f'count={len(symptoms)}')

r = c.get('/api/flora/')
flora = r.json() if r.status_code == 200 else []
mustard = next((f for f in flora if f['name'] == 'সরিষা'), None)
check('GET /api/flora/', r.status_code == 200 and len(flora) == 7, f'count={len(flora)}')
check('ফুলের মাস junction থেকে আসছে', mustard and mustard['months'] == [1, 2, 12],
      f"সরিষার মাস={mustard['months'] if mustard else None}")

r = c.get('/api/farmers/')
farmers = r.json() if r.status_code == 200 else []
check('GET /api/farmers/', r.status_code == 200 and len(farmers) >= 1, f'count={len(farmers)}')
if farmers:
    f = farmers[0]
    check('খামারির জেলা উপজেলার মধ্য দিয়ে আসছে', f['district'] == 'সিরাজগঞ্জ', f['district'])
    check('খামারির ফুল আসল junction থেকে (hardcoded নয়)', f['flora'] == ['সরিষা'], str(f['flora']))
    check('মোট মধু harvests থেকে গোনা', f['honeyProduced'] > 0, str(f['honeyProduced']))
    check('বাক্সের সংখ্যা hives থেকে গোনা', f['hives'] == 5, str(f['hives']))
    check('সক্রিয় বাক্স রানীহীন বাদ দিয়ে', f['activeBoxes'] == 4, str(f['activeBoxes']))

r = c.get('/api/map-farmers/')
check('GET /api/map-farmers/', r.status_code == 200, f'status={r.status_code}')

# ---------- ২. লগ ইন ছাড়া ভেতরের endpoint বন্ধ থাকা উচিত ----------
r = c.get('/api/dashboard/')
check('লগ ইন ছাড়া /api/dashboard/ বন্ধ', r.status_code in (401, 403), f'status={r.status_code}')

# ---------- ৩. লগ ইন ----------
r = c.post('/api/auth/login/', {'phone': '01712345678', 'password': 'demo1234'},
           content_type='application/json')
check('POST /api/auth/login/', r.status_code == 200, f'status={r.status_code}')
user_data = r.json().get('user', {}) if r.status_code == 200 else {}
check('লগ ইনের উত্তরে জেলা-উপজেলা আছে',
      user_data.get('district') == 'সিরাজগঞ্জ' and user_data.get('upazila') == 'উল্লাপাড়া',
      f"{user_data.get('district')}/{user_data.get('upazila')}")
check('খামারের নাম 1:1 profile থেকে আসছে',
      user_data.get('farm') == 'চর ঘাটিনা খামার', str(user_data.get('farm')))
check('অভিজ্ঞতা profile থেকে', user_data.get('exp') == 8, str(user_data.get('exp')))

# ---------- ৪. লগ ইন করা endpoint ----------
r = c.get('/api/dashboard/')
dash = r.json() if r.status_code == 200 else {}
check('GET /api/dashboard/', r.status_code == 200, f'status={r.status_code}')
check('ড্যাশবোর্ডে বাক্স গোনা ঠিক', dash.get('hives_total') == 5, str(dash.get('hives_total')))
check('রানীহীন বাক্স গোনা ঠিক', dash.get('hives_queenless') == 1, str(dash.get('hives_queenless')))
check('বাকি পরিদর্শন তারিখ থেকে হিসেব (১৬ দিন > ১৪)',
      dash.get('overdue_inspections') == 1, str(dash.get('overdue_inspections')))

r = c.get('/api/hives/')
hives = r.json() if r.status_code == 200 else []
check('GET /api/hives/', r.status_code == 200 and len(hives) == 5, f'count={len(hives)}')
by_code = {h['code']: h for h in hives}
check('রানী queens টেবিল থেকে', by_code.get('MK-001', {}).get('queen') == 'আছে',
      str(by_code.get('MK-001', {}).get('queen')))
check('রানীহীন বাক্সে queen="নেই"', by_code.get('MK-009', {}).get('queen') == 'নেই',
      str(by_code.get('MK-009', {}).get('queen')))
# সংখ্যাটা হাতে বসানো যায় না — seed তারিখ ধরে সারি বানায়, তাই একদিন
# পরে ব্যবধান এক বেড়ে যায়। ডাটাবেজ থেকেই হিসেব করে নেওয়া হয়।
from datetime import date as _date  # noqa: E402

_latest = (InspectionModel.objects.filter(hive__code='MK-003')
           .order_by('-inspect_date').first())
MK003_DAYS = (_date.today() - _latest.inspect_date).days if _latest else None

check('শেষ পরিদর্শনের দিন তারিখ থেকে গোনা',
      by_code.get('MK-003', {}).get('last') == MK003_DAYS,
      str(by_code.get('MK-003', {}).get('last')))

r = c.get('/api/farms/')
check('GET /api/farms/', r.status_code == 200 and len(r.json()) == 1, f'status={r.status_code}')

r = c.get('/api/harvests/')
check('GET /api/harvests/', r.status_code == 200, f'count={len(r.json()) if r.status_code == 200 else "-"}')

r = c.get('/api/inspections/')
check('GET /api/inspections/', r.status_code == 200 and len(r.json()) == 5,
      f'count={len(r.json()) if r.status_code == 200 else "-"}')

r = c.get('/api/outbreaks/')
check('GET /api/outbreaks/', r.status_code == 200, f'status={r.status_code}')

# ---------- ৪ক. ভিউ থেকে পড়া রিপোর্টের endpoint ----------
r = c.get('/api/hives/status/')
status_rows = r.json() if r.status_code == 200 else []
by_status = {h['code']: h for h in status_rows}
check('GET /api/hives/status/ (v_hive_status)',
      r.status_code == 200 and len(status_rows) == 5, f'count={len(status_rows)}')
check('ভিউ রানী ঠিক বলছে', by_status.get('MK-009', {}).get('queen') == 'নেই',
      str(by_status.get('MK-009', {}).get('queen')))
check('ভিউ শেষ পরিদর্শনের দিন ঠিক গুনছে',
      by_status.get('MK-003', {}).get('last') == MK003_DAYS,
      str(by_status.get('MK-003', {}).get('last')))
check('ভিউ বাকি পরিদর্শন চিহ্নিত করছে', by_status.get('MK-003', {}).get('overdue') is True,
      str(by_status.get('MK-003', {}).get('overdue')))
check('ভিউয়ের সংখ্যা আর ORM-এর সংখ্যা মিলছে',
      by_status.get('MK-003', {}).get('last') == by_code.get('MK-003', {}).get('last'),
      f"ভিউ={by_status.get('MK-003', {}).get('last')} ORM={by_code.get('MK-003', {}).get('last')}")

r = c.get('/api/hives/status/?overdue=1')
overdue_rows = r.json() if r.status_code == 200 else []
check('GET /api/hives/status/?overdue=1 (v_overdue_hives — ভিউয়ের উপর ভিউ)',
      r.status_code == 200 and len(overdue_rows) == 1 and overdue_rows[0]['code'] == 'MK-003',
      f'count={len(overdue_rows)}')

r = c.get('/api/farms/summary/')
summary = r.json() if r.status_code == 200 else []
check('GET /api/farms/summary/ (v_farm_summary)',
      r.status_code == 200 and len(summary) == 1, f'count={len(summary)}')
if summary:
    s = summary[0]
    check('ভিউ বাক্সের অবস্থা ভাগ করছে',
          s['hive_count'] == 5 and s['strong'] == 3 and s['weak'] == 1 and s['queenless'] == 1,
          f"মোট={s['hive_count']} সবল={s['strong']} দুর্বল={s['weak']} রানীহীন={s['queenless']}")
    check('ভিউ ফুলের তালিকা GROUP_CONCAT থেকে দিচ্ছে', s['flora'] == ['সরিষা'], str(s['flora']))

r = c.get('/api/reports/monthly-honey/')
monthly = r.json() if r.status_code == 200 else []
check('GET /api/reports/monthly-honey/ (v_monthly_honey)',
      r.status_code == 200 and len(monthly) >= 1, f'count={len(monthly)}')
if monthly:
    check('মাসের নাম months টেবিল থেকে বাংলায়',
          monthly[0]['month_name'] in ('নভেম্বর', 'অক্টোবর'), monthly[0]['month_name'])
    check('মাসভিত্তিক মোট মধু ড্যাশবোর্ডের সাথে মেলে',
          sum(m['total_kg'] for m in monthly) == dash.get('honey_this_season'),
          f"ভিউ={sum(m['total_kg'] for m in monthly)} ড্যাশবোর্ড={dash.get('honey_this_season')}")

r = c.get('/api/disease-symptoms/')
matrix = r.json() if r.status_code == 200 else []
check('GET /api/disease-symptoms/ (v_disease_symptoms)',
      r.status_code == 200 and len(matrix) == 8, f'count={len(matrix)}')
varroa = next((m for m in matrix if m['code'] == 'varroa'), None)
check('junction থেকে লক্ষণ গোনা ঠিক',
      varroa is not None and varroa['symptom_count'] == 3 and len(varroa['symptoms']) == 3,
      f"symptom_count={varroa['symptom_count'] if varroa else '-'}")
check('চিকিৎসার ধাপ গোনা ঠিক', varroa is not None and varroa['treat_steps'] == 3,
      f"treat_steps={varroa['treat_steps'] if varroa else '-'}")

# ---------- ৫. নিবন্ধন — আগের bug-টা সারল কি ----------
TEST_PHONE = '01999000111'
User.objects.filter(phone=TEST_PHONE).delete()
fresh = Client()
r = fresh.post('/api/auth/register/', {
    'phone': TEST_PHONE, 'password': 'test1234', 'password2': 'test1234',
    'name': 'পরীক্ষার খামারি', 'role': 'farmer',
    'district': 'পাবনা', 'upazila': 'সুজানগর',
    'farm': 'পরীক্ষা খামার', 'type': 'স্থায়ী', 'exp': 3,
}, content_type='application/json')
check('POST /api/auth/register/', r.status_code == 201, f'status={r.status_code} {r.content[:120]}')

new_user = User.objects.filter(phone=TEST_PHONE).first()
new_farm = Farm.objects.filter(owner=new_user).first() if new_user else None
check('নিবন্ধনে খামার আপনা থেকে তৈরি হলো (আগের bug)', new_farm is not None,
      new_farm.name if new_farm else 'খামার তৈরি হয়নি')
check('খামারের অবস্থান districts টেবিল থেকে বসল',
      new_farm is not None and new_farm.lat is not None,
      f'{new_farm.lat},{new_farm.lng}' if new_farm else '-')

# ---------- ৬. পাসওয়ার্ড বদলের endpoint (আগে ছিল না) ----------
r = fresh.post('/api/auth/password/',
               {'old_password': 'test1234', 'new_password': 'test5678'},
               content_type='application/json')
check('POST /api/auth/password/ (নতুন endpoint)', r.status_code == 200,
      f'status={r.status_code}')
r = Client().post('/api/auth/login/', {'phone': TEST_PHONE, 'password': 'test5678'},
                  content_type='application/json')
check('নতুন পাসওয়ার্ড দিয়ে লগ ইন হয়', r.status_code == 200, f'status={r.status_code}')

# ---------- ৭. স্প্রে নোটিশ → এলাকার খামারিদের সতর্কতা ----------
cropper = Client()
cropper.post('/api/auth/login/', {'phone': '01812345678', 'password': 'demo1234'},
             content_type='application/json')
before = Notification.objects.filter(kind='spray').count()
r = cropper.post('/api/spray-alerts/', {
    'district': 'সিরাজগঞ্জ', 'upazila': 'উল্লাপাড়া', 'crop': 'সরিষা',
    'spray_date': '2026-11-30', 'spray_time': 'সকাল ৮টা', 'chemical': 'ইমিডাক্লোপ্রিড',
    'notes': 'পরীক্ষা',
}, content_type='application/json')
check('POST /api/spray-alerts/', r.status_code == 201, f'status={r.status_code} {r.content[:120]}')
# আইডিটা এখনই ধরে রাখা — শেষে পরিষ্কার করার সময় `r`-এ অন্য উত্তর থাকবে
spray_alert_id = r.json().get('id') if r.status_code == 201 else None
after = Notification.objects.filter(kind='spray').count()
# ঠিক একটা — এলাকায় একজনই খামারি। "একটার বেশি" মানে কাজটা দুবার হচ্ছে
# (আগে Python আর trigger দুটোই করলে এমন হতো), তাই সংখ্যাটা মিলিয়ে দেখা
check('স্প্রে নোটিশ থেকে trigger ঠিক একটা সতর্কতা বানায়', after == before + 1,
      f'{before} → {after}')

# ---------- ৭ক. PROCEDURE-চালিত endpoint ----------
# এই endpoint গুলো ORM-এ সারি বানায় না — sql/07_procedures.sql-এর
# procedure ডাকে। ভুল ডাটা দিলে procedure-এর SIGNAL বার্তা ফিরে আসে।
from django.utils import timezone as dj_timezone  # noqa: E402

from apps.farms.models import Harvest as HarvestModel  # noqa: E402
from apps.farms.models import HiveEvent as HiveEventModel  # noqa: E402

# procedure গুলো hive_events-এ ঘটনা লেখে — শেষে এর পরের সারিগুলো মোছা হয়
proc_started_at = dj_timezone.now()
a_hive_code = 'MK-005'

r = c.post('/api/harvests/', {
    'hive': by_code[a_hive_code]['id'], 'date': '2026-11-23',
    'kg': '7.25', 'moisture': '19.0',
}, content_type='application/json')
check('POST /api/harvests/ (sp_add_harvest)', r.status_code == 201,
      f'status={r.status_code} {r.content[:140]}')
new_harvest_id = r.json().get('id') if r.status_code == 201 else None

r = c.post('/api/harvests/', {
    'hive': by_code[a_hive_code]['id'], 'date': '2026-11-23',
    'kg': '7.25', 'moisture': '42.0',
}, content_type='application/json')
msg = str(r.json().get('detail', '')) if r.status_code == 400 else ''
check('আর্দ্রতা ৪২% দিলে procedure-এর বাংলা বার্তা ফেরে',
      r.status_code == 400 and 'আর্দ্রতা' in msg, f'status={r.status_code} {msg[:60]}')

r = c.post('/api/harvests/', {
    'hive': by_code[a_hive_code]['id'], 'date': '2027-01-01',
    'kg': '5.00', 'moisture': '18.0',
}, content_type='application/json')
check('ভবিষ্যতের তারিখ procedure আটকায়',
      r.status_code == 400 and 'ভবিষ্যতের' in str(r.json().get('detail', '')),
      f'status={r.status_code}')

r = c.post('/api/inspections/', {
    'hive': by_code['MK-002']['id'], 'date': '2026-11-23',
    'frames_filled': 5, 'state': 'সবল', 'queen_seen': True, 'eggs_seen': True,
    'disease_codes': ['varroa', 'নেই-এমন-কোড', 'waxmoth'],
}, content_type='application/json')
check('POST /api/inspections/ (sp_record_inspection)', r.status_code == 201,
      f'status={r.status_code} {r.content[:140]}')
new_inspection_id = r.json().get('id') if r.status_code == 201 else None
check('লুপ ভালো কোডগুলো নিয়েছে, ভুলটা SAVEPOINT দিয়ে বাদ দিয়েছে',
      new_inspection_id is not None
      and InspectionModel.objects.get(pk=new_inspection_id).diseases.count() == 2,
      f'{InspectionModel.objects.get(pk=new_inspection_id).diseases.count() if new_inspection_id else "-"}টা রোগ')

# আলাদা তারিখ, নাহলে uq_one_inspection_per_day আগেই আটকে দেবে আর
# procedure-এর যাচাই পর্যন্ত পৌঁছাবে না
r = c.post('/api/inspections/', {
    'hive': by_code['MK-002']['id'], 'date': '2026-11-19',
    'frames_filled': 99, 'state': 'সবল', 'queen_seen': True, 'eggs_seen': True,
}, content_type='application/json')
check('ভরা ফ্রেম > মোট ফ্রেম procedure আটকায় (CHECK পারে না — অন্য টেবিল)',
      r.status_code == 400 and 'ফ্রেম' in str(r.json().get('detail', '')),
      f"status={r.status_code} {str(r.json().get('detail', ''))[:50]}")

# ---- বাক্স সরানো ----
r = c.post('/api/farms/', {'name': 'যাচাই খামার', 'upazila': 'উল্লাপাড়া',
                           'district_name': 'সিরাজগঞ্জ'},
           content_type='application/json')
temp_farm_id = r.json().get('id') if r.status_code == 201 else None
check('POST /api/farms/ (যাচাইয়ের জন্য দ্বিতীয় খামার)', r.status_code == 201,
      f'status={r.status_code} {r.content[:120]}')

if temp_farm_id:
    r = c.post('/api/hives/MK-001/move/', {'farm': temp_farm_id},
               content_type='application/json')
    check('POST /api/hives/MK-001/move/ (sp_move_hive)',
          r.status_code == 200 and r.json().get('farm') == temp_farm_id,
          f'status={r.status_code} {r.content[:120]}')

    r = c.post('/api/hives/MK-001/move/', {'farm': temp_farm_id},
               content_type='application/json')
    check('একই খামারে আবার সরাতে গেলে procedure আটকায়',
          r.status_code == 400 and 'আগেই' in str(r.json().get('detail', '')),
          f'status={r.status_code}')

    r = c.post('/api/hives/MK-001/move/', {'farm': 999999},
               content_type='application/json')
    check('নেই এমন খামারে সরাতে গেলে আটকায়', r.status_code == 400,
          f'status={r.status_code}')

    # আবার আগের খামারে ফেরানো
    first_farm = Farm.objects.filter(owner__phone='01712345678').exclude(pk=temp_farm_id).first()
    c.post('/api/hives/MK-001/move/', {'farm': first_farm.pk},
           content_type='application/json')

    # ---- audit trigger + middleware একসাথে ----
    # বাক্স সরানোয় hives টেবিল বদলেছে, তাই trg_hive_after_update
    # audit_log-এ সারি লিখেছে। আর actor_id বসেছে কারণ
    # apps/trust/middleware.py প্রতিটা request-এ @app_user_id সেট করে।
    audit = AuditLog.objects.filter(table_name='hives', action='UPDATE').order_by('-id').first()
    check('বাক্স সরানোয় trigger audit_log-এ সারি লিখেছে', audit is not None,
          f'{AuditLog.objects.count()}টা audit সারি')
    check('audit-এ "কে বদলাল" বসেছে (middleware → @app_user_id → trigger)',
          audit is not None and audit.actor_id == user_data.get('id'),
          f'actor={audit.actor_id if audit else "-"} user={user_data.get("id")}')
    check('audit-এ আগের ও নতুন মান JSON-এ আছে',
          audit is not None and audit.old_data.get('farm_id') != audit.new_data.get('farm_id'),
          f'{audit.old_data.get("farm_id") if audit else "-"} → '
          f'{audit.new_data.get("farm_id") if audit else "-"}')

# ---- বেশি ঝুঁকির রোগের সতর্কতা ----
# আগে 'varroa' (high risk) দিয়ে পরিদর্শন লেখা হয়েছে, তাই
# trg_inspection_disease_notify সতর্কতা বানিয়ে থাকার কথা
disease_note = Notification.objects.filter(kind='disease').order_by('-id').first()
check('বেশি ঝুঁকির রোগ পেলে trigger সতর্কতা পাঠায়',
      disease_note is not None and 'ভ্যারোয়া' in disease_note.title,
      disease_note.title if disease_note else 'কোনো সতর্কতা নেই')

r = c.post('/api/hives/remind-overdue/')
check('POST /api/hives/remind-overdue/ (CURSOR)', r.status_code == 200,
      f"status={r.status_code} sent={r.json().get('sent') if r.status_code == 200 else '-'}")

r = c.get('/api/reports/season/?year=2026')
season = r.json() if r.status_code == 200 else {}
check('GET /api/reports/season/ (OUT প্যারামিটার)', r.status_code == 200,
      f'status={r.status_code}')
check('সেরা বাক্স procedure বের করেছে', season.get('best_hive') == 'MK-001',
      str(season.get('best_hive')))

# ---- অন্যের বাক্সে এন্ট্রি আটকায় কিনা ----
other = Client()
other.post('/api/auth/login/', {'phone': '01812345678', 'password': 'demo1234'},
           content_type='application/json')
r = other.post('/api/inspections/', {
    'hive': by_code['MK-001']['id'], 'date': '2026-11-23',
    'frames_filled': 5, 'state': 'সবল', 'queen_seen': True, 'eggs_seen': True,
}, content_type='application/json')
check('অন্য কারো বাক্সে পরিদর্শন লেখা আটকায় (৪০৩)', r.status_code == 403,
      f'status={r.status_code}')

# ---- যাচাইয়ের সারি সরানো ----
if new_harvest_id:
    HarvestModel.objects.filter(pk=new_harvest_id).delete()
if new_inspection_id:
    InspectionModel.objects.filter(pk=new_inspection_id).delete()
if temp_farm_id:
    Farm.objects.filter(pk=temp_farm_id).delete()
HiveEventModel.objects.filter(created_at__gte=proc_started_at).delete()

# trigger গুলোও সারি বানায় — সেগুলোও সরানো দরকার:
#   trg_inspection_disease_notify → kind='disease' সতর্কতা
#   trg_hive_after_update / trg_harvest_after_delete → audit_log
# seed-করা অবস্থায় এই দুই টেবিল খালি থাকে, তাই পুরোটাই মোছা হয়
Notification.objects.filter(kind__in=['inspection', 'disease']).delete()
AuditLog.objects.all().delete()


# ---------- ৮. ডাটাবেজের CHECK constraint আসলেই আটকায় কিনা ----------
# অ্যাপের যাচাই বাইপাস করে সরাসরি ORM দিয়ে ভুল ডাটা ঢোকানোর চেষ্টা।
# ডাটাবেজ আটকালে IntegrityError আসবে — সেটাই আমরা চাই।
from decimal import Decimal  # noqa: E402

from django.db import DatabaseError, transaction  # noqa: E402

from apps.common import proc_message  # noqa: E402
from apps.farms.models import Harvest, Hive  # noqa: E402


def rejects(label, make):
    """make() চালিয়ে দেখা হয় ডাটাবেজ আটকায় কিনা।

    DatabaseError ধরা হয়, কারণ দুই রকম ভুল আসতে পারে:
      • CHECK / UNIQUE / FOREIGN KEY ভাঙলে → IntegrityError
      • trigger-এর SIGNAL SQLSTATE '45000' → OperationalError
    দুটোই DatabaseError-এর সন্তান, আর দুটোই মানে "ডাটাবেজ নেয়নি"।
    """
    try:
        with transaction.atomic():
            make()
    except DatabaseError as exc:
        text = str(exc)
        # CHECK-এর ভুলে constraint-এর নাম উদ্ধৃতিতে থাকে; SIGNAL-এ
        # থাকে বাংলা বার্তা
        detail = text.split("'")[1] if "Check constraint" in text else proc_message(exc)
        check(label, True, detail[:60])
        return
    except Exception as exc:
        check(label, False, f'অন্য ভুল: {type(exc).__name__}')
        return
    check(label, False, 'ঢুকে গেছে — আটকায়নি')


a_hive = Hive.objects.first()

rejects('আর্দ্রতা ৪২% আটকায় (chk_harvest_moisture)',
        lambda: Harvest.objects.create(hive=a_hive, harvest_date='2026-11-20',
                                       kg=Decimal('10'), moisture=Decimal('42')))

rejects('ঋণাত্মক পরিমাণ মধু আটকায় (chk_harvest_kg_positive)',
        lambda: Harvest.objects.create(hive=a_hive, harvest_date='2026-11-20',
                                       kg=Decimal('-5'), moisture=Decimal('18')))

rejects('ভরা ফ্রেম > মোট ফ্রেম আটকায় (chk_hive_filled_within_frames)',
        lambda: Hive.objects.filter(pk=a_hive.pk).update(filled=99))

rejects('ভুল মোবাইল format আটকায় (chk_user_phone_format)',
        lambda: User.objects.create_user(phone='01212345678', password='x',
                                         name='ভুল নম্বর', role='farmer'))

# ---------- ৯. TRIGGER যা CHECK পারে না ----------
from datetime import date  # noqa: E402

from apps.farms.models import Queen as QueenModel  # noqa: E402

queened_hive = (Hive.objects.filter(queens__removed_on__isnull=True)
                .distinct().first())

rejects('এক বাক্সে দুজন চলতি রানী আটকায় (trg_queen_before_insert)',
        lambda: QueenModel.objects.create(hive=queened_hive, source='পরীক্ষা',
                                          installed_on=date(2026, 11, 1)))

rejects('ভবিষ্যতের তারিখে মধু আটকায় (trg_harvest_before_insert)',
        lambda: Harvest.objects.create(hive=a_hive, harvest_date=date(2027, 6, 1),
                                       kg=Decimal('5'), moisture=Decimal('18')))

rejects('ভবিষ্যতের তারিখে পরিদর্শন আটকায় (trg_inspection_before_insert)',
        lambda: InspectionModel.objects.create(hive=a_hive, inspect_date=date(2027, 6, 1),
                                               frames_filled=3, state='সবল'))

# ---------- পরিষ্কার ----------
# যাচাইয়ের সময় তৈরি হওয়া সারি সরিয়ে দেওয়া হয়, যাতে বারবার চালালেও
# ডাটাবেজে পরীক্ষার আবর্জনা জমে না
User.objects.filter(phone=TEST_PHONE).delete()
if spray_alert_id:
    Notification.objects.filter(ref_table='spray_alerts', ref_id=spray_alert_id).delete()
    SprayAlert.objects.filter(pk=spray_alert_id).delete()

print()
print(f'মোট {len(PASS) + len(FAIL)}টি যাচাই — পাস {len(PASS)}, ব্যর্থ {len(FAIL)}')
if FAIL:
    print('ব্যর্থ:')
    for item in FAIL:
        print('  -', item)
sys.exit(1 if FAIL else 0)
