from django.db import models


class Disease(models.Model):
    RISK = [('high', 'বেশি'), ('mid', 'মাঝারি'), ('low', 'কম')]

    disease_id = models.CharField(max_length=20, unique=True, verbose_name='আইডি')
    name = models.CharField(max_length=100, verbose_name='রোগের নাম')
    kind = models.CharField(max_length=50, verbose_name='ধরন')
    risk = models.CharField(max_length=5, choices=RISK, verbose_name='ঝুঁকি')
    signs = models.TextField(verbose_name='লক্ষণ (JSON)')
    prevent = models.TextField(verbose_name='প্রতিরোধ (JSON)')
    treat = models.TextField(verbose_name='চিকিৎসা (JSON)')

    class Meta:
        db_table = 'diseases'
        verbose_name = 'রোগ'

    def __str__(self):
        return self.name


class Flora(models.Model):
    name = models.CharField(max_length=80, verbose_name='ফুলের নাম')
    where = models.CharField(max_length=200, verbose_name='কোথায়')
    months = models.CharField(max_length=50, verbose_name='মাস (JSON)')
    is_dearth = models.BooleanField(default=False, verbose_name='ফুল কম মৌসুম')

    class Meta:
        db_table = 'flora'
        verbose_name = 'ফুল'

    def __str__(self):
        return self.name


class Outbreak(models.Model):
    disease_name = models.CharField(max_length=100, verbose_name='রোগ')
    where = models.CharField(max_length=100, verbose_name='কোথায়')
    farms_affected = models.PositiveSmallIntegerField(verbose_name='আক্রান্ত খামার')
    alert = models.BooleanField(default=False, verbose_name='সতর্কতা')
    reported_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'outbreaks'
        ordering = ['-reported_at']
        verbose_name = 'রোগ বিস্তার'
