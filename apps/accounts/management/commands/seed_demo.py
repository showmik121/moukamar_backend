"""ডেমো ব্যবহারকারী ও নমুনা খামার তৈরি করে।

sql/10_seed.sql শুধু reference ডাটা (জেলা, রোগ, ফুল) ভরে। পাসওয়ার্ড
Django-র নিজের hash দিয়ে বসাতে হয়, তাই ব্যবহারকারী SQL থেকে নয়,
এই command থেকে তৈরি হয়।

frontend-এর store.js-এ যে দুটো demo লগ ইন লেখা আছে, হুবহু সেগুলোই
বানানো হয় — তাই লগ ইন পাতার "demo তথ্য বসান" বোতাম আসল backend-এও কাজ করে।

চালানো:  python manage.py seed_demo
আবার চালালে ডুপ্লিকেট হয় না (phone ধরে খোঁজে)।
"""

from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import CropperProfile, FarmerProfile, User
from apps.alerts.models import Notification, SprayAlert
from apps.farms.models import Farm, Harvest, Hive, HiveEvent, Inspection, Queen
from apps.locations.utils import district_point, resolve_upazila
from apps.reference.models import BeeSpecies, Crop, Flora

DEMO_FARMER = {'phone': '01712345678', 'name': 'রহিম উদ্দিন', 'district': 'সিরাজগঞ্জ',
               'upazila': 'উল্লাপাড়া', 'farm': 'চর ঘাটিনা খামার', 'exp': 8}
DEMO_CROPPER = {'phone': '01812345678', 'name': 'মো. আলমগীর', 'district': 'সিরাজগঞ্জ',
                'upazila': 'উল্লাপাড়া', 'crop': 'সরিষা'}
DEMO_PASSWORD = 'demo1234'
# অ্যাপের অ্যাডমিন (role='admin') — Django-র /admin/ প্যানেলে ঢোকার অধিকার নেই
# (is_staff নয়), সেটার জন্য আলাদা করে createsuperuser চালাতে হয়
DEMO_ADMIN = {'email': 'admin@moukhamar.com', 'name': 'সিস্টেম অ্যাডমিন', 'password': 'admin1234'}

# frontend-এর data.js-এর HIVES থেকে — (কোড, প্রজাতি, ফ্রেম, ভরা, অবস্থা, শেষ পরিদর্শন কত দিন আগে)
SAMPLE_HIVES = [
    ('MK-001', 'Apis mellifera', 10, 7, 'সবল', 3),
    ('MK-002', 'Apis mellifera', 10, 5, 'সবল', 3),
    ('MK-003', 'Apis mellifera', 8, 2, 'দুর্বল', 16),
    ('MK-005', 'Apis cerana', 8, 4, 'সবল', 4),
    ('MK-009', 'Apis mellifera', 10, 0, 'রানীহীন', 2),
]


class Command(BaseCommand):
    help = 'ডেমো ব্যবহারকারী ও নমুনা খামার তৈরি করে'

    def add_arguments(self, parser):
        parser.add_argument(
            '--reset', action='store_true',
            help='আগের ডেমো খামার ও বাক্স মুছে নতুন করে বানায়। '
                 'queries/ ফোল্ডারের demo ফাইল মাঝপথে থেমে গেলে এটা চালিয়ে '
                 'ডাটাবেজ আগের অবস্থায় ফিরিয়ে আনা যায়।',
        )

    @transaction.atomic
    def handle(self, *args, **options):
        today = timezone.localdate()

        if options['reset']:
            # খামার মুছলে বাক্স, রানী, পরিদর্শন, মধু — সব CASCADE-এ যায়
            removed = Farm.objects.filter(owner__phone=DEMO_FARMER['phone']).delete()[0]
            Notification.objects.filter(recipient__phone=DEMO_FARMER['phone']).delete()
            SprayAlert.objects.filter(cropper__phone=DEMO_CROPPER['phone']).delete()
            self.stdout.write(self.style.WARNING(f'আগের ডেমো ডাটা মুছে ফেলা হলো ({removed}টা সারি)'))

        # ---- খামারি ----
        farmer = User.objects.filter(phone=DEMO_FARMER['phone']).first()
        if farmer:
            self.stdout.write('খামারি আগেই আছে — নতুন করে তৈরি করা হলো না')
        else:
            upazila = resolve_upazila(DEMO_FARMER['district'], DEMO_FARMER['upazila'])
            farmer = User.objects.create_user(
                phone=DEMO_FARMER['phone'], password=DEMO_PASSWORD,
                name=DEMO_FARMER['name'], role='farmer', upazila=upazila)
            FarmerProfile.objects.create(
                user=farmer, farm_name=DEMO_FARMER['farm'], farm_type='ভ্রাম্যমাণ',
                experience_years=DEMO_FARMER['exp'], rating=Decimal('4.8'))
            self.stdout.write(self.style.SUCCESS(f'খামারি তৈরি: {farmer.name}'))

        # ---- কৃষক ----
        if User.objects.filter(phone=DEMO_CROPPER['phone']).exists():
            self.stdout.write('কৃষক আগেই আছে')
        else:
            upazila = resolve_upazila(DEMO_CROPPER['district'], DEMO_CROPPER['upazila'])
            cropper = User.objects.create_user(
                phone=DEMO_CROPPER['phone'], password=DEMO_PASSWORD,
                name=DEMO_CROPPER['name'], role='cropper', upazila=upazila)
            CropperProfile.objects.create(
                user=cropper, main_crop=Crop.objects.get_or_create(name=DEMO_CROPPER['crop'])[0])
            self.stdout.write(self.style.SUCCESS(f'কৃষক তৈরি: {cropper.name}'))

        # ---- অ্যাডমিন ----
        if User.objects.filter(email=DEMO_ADMIN['email']).exists():
            self.stdout.write('অ্যাডমিন আগেই আছে')
        else:
            User.objects.create_user(phone=None, email=DEMO_ADMIN['email'],
                                     password=DEMO_ADMIN['password'],
                                     name=DEMO_ADMIN['name'], role='admin')
            self.stdout.write(self.style.SUCCESS(f'অ্যাডমিন তৈরি: {DEMO_ADMIN["email"]}'))

        # ---- খামার ----
        farm = Farm.objects.filter(owner=farmer, name=DEMO_FARMER['farm']).first()
        if not farm:
            lat, lng = district_point(DEMO_FARMER['district'])
            farm = Farm.objects.create(
                owner=farmer, name=DEMO_FARMER['farm'],
                upazila=resolve_upazila(DEMO_FARMER['district'], DEMO_FARMER['upazila']),
                farm_type='ভ্রাম্যমাণ', status='সক্রিয়',
                established_on=today - timedelta(days=400), lat=lat, lng=lng)
            mustard = Flora.objects.filter(name='সরিষা').first()
            if mustard:
                farm.flora.add(mustard)
            self.stdout.write(self.style.SUCCESS(f'খামার তৈরি: {farm.name}'))

        # ---- বাক্স, রানী, পরিদর্শন, মধু ----
        created = 0
        for code, species_name, frames, filled, state, last_days in SAMPLE_HIVES:
            if Hive.objects.filter(code=code).exists():
                continue
            species, _ = BeeSpecies.objects.get_or_create(name=species_name)
            hive = Hive.objects.create(
                code=code, farm=farm, species=species, frames=frames,
                filled=filled, state=state, installed_on=today - timedelta(days=300))

            # রানীহীন বাক্সে চলতি রানী থাকবে না — তাই API-তে queen='নেই' আসবে
            if state != 'রানীহীন':
                Queen.objects.create(hive=hive, source='নিজের খামার', color_mark='সবুজ',
                                     installed_on=today - timedelta(days=280))

            inspection = Inspection.objects.create(
                hive=hive, inspector=farmer, inspect_date=today - timedelta(days=last_days),
                frames_filled=filled, state=state,
                queen_seen=(state != 'রানীহীন'), eggs_seen=(state == 'সবল'),
                notes='নমুনা পরিদর্শন')
            HiveEvent.objects.create(hive=hive, actor=farmer, event_date=inspection.inspect_date,
                                     kind='inspect', note=f'পরিদর্শন — {state}')

            if filled >= 5:
                Harvest.objects.create(
                    hive=hive, harvester=farmer, flora=Flora.objects.filter(name='সরিষা').first(),
                    harvest_date=today - timedelta(days=20),
                    kg=Decimal('12.50'), moisture=Decimal('19.5'), notes='নমুনা সংগ্রহ')
            created += 1

        if created:
            self.stdout.write(self.style.SUCCESS(f'{created}টি বাক্স তৈরি হয়েছে'))
        else:
            self.stdout.write('বাক্স আগেই ছিল')

        self.stdout.write(self.style.SUCCESS('ডেমো ডাটা প্রস্তুত'))
