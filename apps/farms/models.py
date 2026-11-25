from django.db import models


class Farm(models.Model):
    """farms (আগের নাম apiaries) — একজন খামারির এক বা একাধিক খামার।

    `flora` আগে একটাই string ছিল, অথচ API একাধিক ফুলের তালিকা পাঠাত —
    তাই farm_flora junction দিয়ে M:N করা হলো।
    """

    STATUS = [('সক্রিয়', 'সক্রিয়'), ('বিশ্রামে', 'বিশ্রামে'), ('বন্ধ', 'বন্ধ')]
    FARM_TYPE = [('স্থায়ী', 'স্থায়ী'), ('ভ্রাম্যমাণ', 'ভ্রাম্যমাণ')]

    owner = models.ForeignKey('accounts.User', on_delete=models.CASCADE,
                              related_name='farms', verbose_name='মালিক')
    name = models.CharField(max_length=120, verbose_name='খামারের নাম')
    upazila = models.ForeignKey('locations.Upazila', on_delete=models.PROTECT,
                                related_name='farms', verbose_name='উপজেলা')
    farm_type = models.CharField(max_length=15, choices=FARM_TYPE, default='স্থায়ী', verbose_name='ধরন')
    status = models.CharField(max_length=15, choices=STATUS, default='সক্রিয়', verbose_name='অবস্থা')
    established_on = models.DateField(null=True, blank=True, verbose_name='শুরুর তারিখ')
    lat = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True, verbose_name='অক্ষাংশ')
    lng = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True, verbose_name='দ্রাঘিমাংশ')
    flora = models.ManyToManyField('reference.Flora', db_table='farm_flora', blank=True,
                                   related_name='farms', verbose_name='প্রধান ফুল')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'farms'
        ordering = ['name']
        indexes = [
            models.Index(fields=['owner'], name='ix_farm_owner'),
            models.Index(fields=['upazila', 'status'], name='ix_farm_upazila_status'),
        ]
        verbose_name = 'খামার'
        verbose_name_plural = 'খামার'

    def __str__(self):
        return self.name


class Hive(models.Model):
    """hives — মৌবাক্স।

    রানীর ঘরগুলো (queen, queen_age, queen_source, queen_color) সরিয়ে
    queens টেবিলে নেওয়া হয়েছে, যাতে রানী বদলের ইতিহাস থাকে।
    last_inspection_days কলামটাও বাদ — ওটা হিসেব করা মান, তাই
    v_hive_status ভিউতে DATEDIFF দিয়ে বের করা হবে।
    """

    STATE_CHOICES = [('সবল', 'সবল'), ('দুর্বল', 'দুর্বল'), ('রানীহীন', 'রানীহীন')]

    code = models.CharField(max_length=20, unique=True, verbose_name='কোড')
    farm = models.ForeignKey(Farm, on_delete=models.CASCADE,
                             related_name='hives', verbose_name='খামার')
    species = models.ForeignKey('reference.BeeSpecies', on_delete=models.PROTECT,
                                related_name='hives', verbose_name='প্রজাতি')
    frames = models.PositiveSmallIntegerField(default=10, verbose_name='ফ্রেম সংখ্যা')
    filled = models.PositiveSmallIntegerField(default=0, verbose_name='ভরা ফ্রেম')
    state = models.CharField(max_length=15, choices=STATE_CHOICES, default='সবল', verbose_name='অবস্থা')
    installed_on = models.DateField(null=True, blank=True, verbose_name='বসানোর তারিখ')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'hives'
        ordering = ['code']
        indexes = [
            models.Index(fields=['farm', 'state'], name='ix_hive_farm_state'),
        ]
        verbose_name = 'বাক্স'
        verbose_name_plural = 'বাক্স'

    def __str__(self):
        return self.code

    @property
    def current_queen(self):
        return self.queens.filter(removed_on__isnull=True).first()


class Queen(models.Model):
    """queens — এক বাক্সে রানীর ইতিহাস (1:M)।

    চলতি রানী = removed_on IS NULL। রানীর বয়স installed_on থেকে হিসেব হয়,
    তাই আলাদা queen_age কলাম রাখার দরকার নেই।
    """

    hive = models.ForeignKey(Hive, on_delete=models.CASCADE,
                             related_name='queens', verbose_name='বাক্স')
    source = models.CharField(max_length=80, blank=True, verbose_name='উৎস')
    color_mark = models.CharField(max_length=20, blank=True, verbose_name='রঙের চিহ্ন')
    installed_on = models.DateField(verbose_name='বসানোর তারিখ')
    removed_on = models.DateField(null=True, blank=True, verbose_name='সরানোর তারিখ')
    note = models.CharField(max_length=200, blank=True, verbose_name='মন্তব্য')

    class Meta:
        db_table = 'queens'
        ordering = ['-installed_on']
        indexes = [models.Index(fields=['hive', 'removed_on'], name='ix_queen_hive_active')]
        verbose_name = 'রানী'
        verbose_name_plural = 'রানী'

    def __str__(self):
        return f'{self.hive.code} — রানী ({self.installed_on})'


class HiveEvent(models.Model):
    """hive_events — বাক্সের ঘটনার তালিকা (hive.html-এর ইতিহাস অংশ)।"""

    KIND = [
        ('inspect', 'পরিদর্শন'), ('harvest', 'মধু সংগ্রহ'), ('queen', 'রানী'),
        ('move', 'স্থান বদল'), ('disease', 'রোগ'), ('other', 'অন্যান্য'),
    ]

    hive = models.ForeignKey(Hive, on_delete=models.CASCADE,
                             related_name='events', verbose_name='বাক্স')
    actor = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True,
                              related_name='hive_events', verbose_name='কে করল')
    event_date = models.DateField(verbose_name='তারিখ')
    kind = models.CharField(max_length=10, choices=KIND, verbose_name='ধরন')
    note = models.CharField(max_length=300, verbose_name='বিবরণ')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'hive_events'
        ordering = ['-event_date', '-id']
        indexes = [models.Index(fields=['hive', '-event_date'], name='ix_hive_event_date')]
        verbose_name = 'বাক্সের ঘটনা'
        verbose_name_plural = 'বাক্সের ঘটনা'

    def __str__(self):
        return f'{self.hive.code} — {self.note[:30]}'


class Inspection(models.Model):
    """inspections — পরিদর্শন।

    disease_signs TEXT কলামের বদলে inspection_diseases junction —
    এক পরিদর্শনে একাধিক রোগ পাওয়া যেতে পারে, মাত্রা সহ।
    """

    hive = models.ForeignKey(Hive, on_delete=models.CASCADE,
                             related_name='inspections', verbose_name='বাক্স')
    inspector = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True,
                                  related_name='inspections', verbose_name='পরিদর্শক')
    inspect_date = models.DateField(verbose_name='তারিখ')
    frames_filled = models.PositiveSmallIntegerField(verbose_name='ভরা ফ্রেম')
    state = models.CharField(max_length=15, choices=Hive.STATE_CHOICES, verbose_name='অবস্থা')
    queen_seen = models.BooleanField(default=True, verbose_name='রানী দেখা গেছে')
    eggs_seen = models.BooleanField(default=True, verbose_name='ডিম দেখা গেছে')
    notes = models.TextField(blank=True, verbose_name='মন্তব্য')
    diseases = models.ManyToManyField('reference.Disease', through='InspectionDisease',
                                      related_name='inspections', verbose_name='পাওয়া রোগ')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'inspections'
        ordering = ['-inspect_date']
        constraints = [
            models.UniqueConstraint(fields=['hive', 'inspect_date'], name='uq_one_inspection_per_day'),
        ]
        indexes = [models.Index(fields=['-inspect_date'], name='ix_inspection_date')]
        verbose_name = 'পরিদর্শন'
        verbose_name_plural = 'পরিদর্শন'

    def __str__(self):
        return f'{self.hive.code} — {self.inspect_date}'


class InspectionDisease(models.Model):
    """inspection_diseases — M:N junction, বাড়তি ঘর severity সহ।"""

    SEVERITY = [('low', 'অল্প'), ('mid', 'মাঝারি'), ('high', 'বেশি')]

    inspection = models.ForeignKey(Inspection, on_delete=models.CASCADE, verbose_name='পরিদর্শন')
    disease = models.ForeignKey('reference.Disease', on_delete=models.CASCADE, verbose_name='রোগ')
    severity = models.CharField(max_length=5, choices=SEVERITY, default='mid', verbose_name='মাত্রা')

    class Meta:
        db_table = 'inspection_diseases'
        constraints = [
            models.UniqueConstraint(fields=['inspection', 'disease'], name='uq_inspection_disease'),
        ]
        verbose_name = 'পরিদর্শনে পাওয়া রোগ'
        verbose_name_plural = 'পরিদর্শনে পাওয়া রোগ'

    def __str__(self):
        return f'{self.inspection_id} — {self.disease_id}'


class Harvest(models.Model):
    """harvests — মধু সংগ্রহ। আর্দ্রতার সীমা CHECK constraint-এ বসবে।"""

    hive = models.ForeignKey(Hive, on_delete=models.CASCADE,
                             related_name='harvests', verbose_name='বাক্স')
    harvester = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True,
                                  related_name='harvests', verbose_name='সংগ্রহকারী')
    flora = models.ForeignKey('reference.Flora', on_delete=models.SET_NULL, null=True, blank=True,
                              related_name='harvests', verbose_name='ফুলের উৎস')
    harvest_date = models.DateField(verbose_name='তারিখ')
    kg = models.DecimalField(max_digits=7, decimal_places=2, verbose_name='মধু (কেজি)')
    moisture = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True,
                                   verbose_name='আর্দ্রতা (%)')
    notes = models.TextField(blank=True, verbose_name='মন্তব্য')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'harvests'
        ordering = ['-harvest_date']
        indexes = [
            models.Index(fields=['-harvest_date'], name='ix_harvest_date'),
            models.Index(fields=['hive', '-harvest_date'], name='ix_harvest_hive_date'),
        ]
        verbose_name = 'মধু সংগ্রহ'
        verbose_name_plural = 'মধু সংগ্রহ'

    def __str__(self):
        return f'{self.hive.code} — {self.kg} কেজি'
