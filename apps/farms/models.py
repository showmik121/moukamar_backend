from django.db import models
from apps.accounts.models import User


class Farm(models.Model):
    """apiaries table"""
    STATUS = [('সক্রিয়', 'সক্রিয়'), ('বিশ্রামে', 'বিশ্রামে'), ('বন্ধ', 'বন্ধ')]

    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='farms', verbose_name='মালিক')
    name = models.CharField(max_length=120, verbose_name='খামারের নাম')
    upazila = models.CharField(max_length=60, verbose_name='উপজেলা')
    district = models.CharField(max_length=60, verbose_name='জেলা')
    flora = models.CharField(max_length=80, blank=True, verbose_name='প্রধান ফুল')
    status = models.CharField(max_length=15, choices=STATUS, default='সক্রিয়', verbose_name='অবস্থা')
    lat = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True, verbose_name='অক্ষাংশ')
    lng = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True, verbose_name='দ্রাঘিমাংশ')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'apiaries'
        verbose_name = 'খামার'

    def __str__(self):
        return self.name


class Hive(models.Model):
    """hives table"""
    QUEEN_CHOICES = [('আছে', 'আছে'), ('নেই', 'নেই')]
    STATE_CHOICES = [('সবল', 'সবল'), ('দুর্বল', 'দুর্বল'), ('রানীহীন', 'রানীহীন')]

    code = models.CharField(max_length=20, unique=True, verbose_name='কোড')
    farm = models.ForeignKey(Farm, on_delete=models.CASCADE, related_name='hives', verbose_name='খামার')
    species = models.CharField(max_length=50, default='Apis mellifera', verbose_name='প্রজাতি')
    frames = models.PositiveSmallIntegerField(default=10, verbose_name='ফ্রেম সংখ্যা')
    filled = models.PositiveSmallIntegerField(default=0, verbose_name='ভরা ফ্রেম')
    state = models.CharField(max_length=15, choices=STATE_CHOICES, default='সবল', verbose_name='অবস্থা')
    queen = models.CharField(max_length=5, choices=QUEEN_CHOICES, default='আছে', verbose_name='রানী')
    queen_age = models.PositiveSmallIntegerField(default=1, verbose_name='রানীর বয়স (বছর)')
    queen_source = models.CharField(max_length=80, blank=True, verbose_name='রানীর উৎস')
    queen_color = models.CharField(max_length=20, blank=True, verbose_name='রানীর রঙের চিহ্ন')
    last_inspection_days = models.PositiveSmallIntegerField(default=0, verbose_name='শেষ পরিদর্শনের দিন')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'hives'
        verbose_name = 'বাক্স'

    def __str__(self):
        return self.code


class Inspection(models.Model):
    """inspections table"""
    hive = models.ForeignKey(Hive, on_delete=models.CASCADE, related_name='inspections', verbose_name='বাক্স')
    inspector = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='inspections', verbose_name='পরিদর্শক')
    date = models.DateField(verbose_name='তারিখ')
    frames_filled = models.PositiveSmallIntegerField(verbose_name='ভরা ফ্রেম')
    state = models.CharField(max_length=15, verbose_name='অবস্থা')
    queen_seen = models.BooleanField(default=True, verbose_name='রানী দেখা গেছে')
    eggs_seen = models.BooleanField(default=True, verbose_name='ডিম দেখা গেছে')
    disease_signs = models.TextField(blank=True, verbose_name='রোগের লক্ষণ')
    notes = models.TextField(blank=True, verbose_name='মন্তব্য')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'inspections'
        ordering = ['-date']
        verbose_name = 'পরিদর্শন'


class Harvest(models.Model):
    """harvests table"""
    hive = models.ForeignKey(Hive, on_delete=models.CASCADE, related_name='harvests', verbose_name='বাক্স')
    harvester = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, verbose_name='সংগ্রহকারী')
    date = models.DateField(verbose_name='তারিখ')
    kg = models.DecimalField(max_digits=7, decimal_places=2, verbose_name='মধু (কেজি)')
    moisture = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True, verbose_name='আর্দ্রতা (%)')
    flora = models.CharField(max_length=60, blank=True, verbose_name='ফুলের উৎস')
    notes = models.TextField(blank=True, verbose_name='মন্তব্য')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'harvests'
        ordering = ['-date']
        verbose_name = 'মধু সংগ্রহ'
