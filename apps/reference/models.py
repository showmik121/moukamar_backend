from django.db import models


class Month(models.Model):
    """months — ১–১২, বাংলা নাম সহ। ফুলের ক্যালেন্ডারের জন্য lookup।"""

    month_no = models.PositiveSmallIntegerField(primary_key=True, verbose_name='মাস')
    name_bn = models.CharField(max_length=20, verbose_name='বাংলা নাম')

    class Meta:
        db_table = 'months'
        ordering = ['month_no']
        verbose_name = 'মাস'
        verbose_name_plural = 'মাস'

    def __str__(self):
        return self.name_bn


class Crop(models.Model):
    """crops — কৃষকের ফসলের তালিকা (আগে users-এ string ছিল)।"""

    name = models.CharField(max_length=50, unique=True, verbose_name='ফসল')

    class Meta:
        db_table = 'crops'
        ordering = ['name']
        verbose_name = 'ফসল'
        verbose_name_plural = 'ফসল'

    def __str__(self):
        return self.name


class BeeSpecies(models.Model):
    """bee_species — বাংলাদেশের মধু মৌমাছির প্রকার (bees.html)।"""

    name = models.CharField(max_length=60, unique=True, verbose_name='নাম')
    sci_name = models.CharField(max_length=80, blank=True, verbose_name='বৈজ্ঞানিক নাম')
    note = models.TextField(blank=True, verbose_name='পরিচিতি')

    class Meta:
        db_table = 'bee_species'
        ordering = ['name']
        verbose_name = 'মৌমাছির প্রকার'
        verbose_name_plural = 'মৌমাছির প্রকার'

    def __str__(self):
        return self.name


class Flora(models.Model):
    """flora — মধুর উৎস ফুল।

    আগে `months` কলামে "[12,1,2]" string থাকত — 1NF ভাঙত।
    এখন flora_blooms junction টেবিল দিয়ে মাসের সাথে M:N।
    """

    name = models.CharField(max_length=80, unique=True, verbose_name='ফুল')
    where_found = models.CharField(max_length=200, blank=True, verbose_name='কোথায়')
    is_dearth = models.BooleanField(default=False, verbose_name='ফুল কম মৌসুম')
    blooms = models.ManyToManyField(Month, db_table='flora_blooms',
                                   related_name='flora', verbose_name='যে মাসে ফোটে')

    class Meta:
        db_table = 'flora'
        ordering = ['name']
        verbose_name = 'ফুল'
        verbose_name_plural = 'ফুল'

    def __str__(self):
        return self.name


class Symptom(models.Model):
    """symptoms — রোগের লক্ষণ। diseases.html-এ এগুলো বাছলে রোগ ফিল্টার হয়।"""

    code = models.CharField(max_length=10, unique=True, verbose_name='কোড')
    name = models.CharField(max_length=120, verbose_name='লক্ষণ')

    class Meta:
        db_table = 'symptoms'
        ordering = ['code']
        verbose_name = 'লক্ষণ'
        verbose_name_plural = 'লক্ষণ'

    def __str__(self):
        return self.name


class Disease(models.Model):
    """diseases — রোগ ও শত্রু।

    আগে signs/prevent/treat তিনটা TEXT কলামে JSON string ছিল (1NF ভাঙত)।
    এখন লক্ষণ গেছে disease_symptoms junction-এ, আর চিকিৎসা ও প্রতিরোধের
    ধাপগুলো গেছে disease_steps টেবিলে — ক্রম সহ।
    """

    RISK = [('high', 'বেশি'), ('mid', 'মাঝারি'), ('low', 'কম')]

    code = models.CharField(max_length=20, unique=True, verbose_name='কোড')
    name = models.CharField(max_length=100, verbose_name='নাম')
    kind = models.CharField(max_length=50, verbose_name='ধরন')
    risk = models.CharField(max_length=5, choices=RISK, verbose_name='ঝুঁকি')
    cause = models.TextField(blank=True, verbose_name='কারণ')
    spread = models.TextField(blank=True, verbose_name='কীভাবে ছড়ায়')
    symptoms = models.ManyToManyField(Symptom, db_table='disease_symptoms',
                                     related_name='diseases', verbose_name='লক্ষণ')

    class Meta:
        db_table = 'diseases'
        ordering = ['name']
        indexes = [models.Index(fields=['risk'], name='ix_disease_risk')]
        verbose_name = 'রোগ'
        verbose_name_plural = 'রোগ'

    def __str__(self):
        return self.name


class DiseaseStep(models.Model):
    """disease_steps — চিকিৎসা ও প্রতিরোধের ধাপ, ক্রম মেনে।"""

    KIND = [('sign', 'লক্ষণের বর্ণনা'), ('prevent', 'প্রতিরোধ'), ('treat', 'চিকিৎসা')]

    disease = models.ForeignKey(Disease, on_delete=models.CASCADE,
                                related_name='steps', verbose_name='রোগ')
    kind = models.CharField(max_length=10, choices=KIND, verbose_name='ধরন')
    step_no = models.PositiveSmallIntegerField(verbose_name='ক্রম')
    text = models.CharField(max_length=300, verbose_name='লেখা')

    class Meta:
        db_table = 'disease_steps'
        ordering = ['disease', 'kind', 'step_no']
        constraints = [
            models.UniqueConstraint(fields=['disease', 'kind', 'step_no'], name='uq_disease_step_order'),
        ]
        verbose_name = 'রোগের ধাপ'
        verbose_name_plural = 'রোগের ধাপ'

    def __str__(self):
        return f'{self.disease.name} — {self.get_kind_display()} {self.step_no}'
