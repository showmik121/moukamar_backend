from django.db import models


class District(models.Model):
    """districts — বাংলাদেশের ৬৪ জেলা।

    lat/lng এখানে রাখা হয়েছে বলেই নতুন নিবন্ধনের সময় ম্যাপের অবস্থান
    জেলা থেকে পাওয়া যায়। আগে এটা কোডে hardcoded ছিল (DISTRICT_COORDS)
    আর ব্যবহারকারীর সারিতে জেলার নাম বারবার লেখা হতো — 3NF ভাঙছিল।
    """

    name = models.CharField(max_length=60, unique=True, verbose_name='জেলা')
    lat = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True, verbose_name='অক্ষাংশ')
    lng = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True, verbose_name='দ্রাঘিমাংশ')

    class Meta:
        db_table = 'districts'
        ordering = ['name']
        verbose_name = 'জেলা'
        verbose_name_plural = 'জেলা'

    def __str__(self):
        return self.name


class Upazila(models.Model):
    """upazilas — এক জেলার অনেক উপজেলা (1:M)।"""

    district = models.ForeignKey(District, on_delete=models.CASCADE,
                                related_name='upazilas', verbose_name='জেলা')
    name = models.CharField(max_length=60, verbose_name='উপজেলা')

    class Meta:
        db_table = 'upazilas'
        ordering = ['district__name', 'name']
        constraints = [
            models.UniqueConstraint(fields=['district', 'name'], name='uq_upazila_per_district'),
        ]
        indexes = [models.Index(fields=['name'], name='ix_upazila_name')]
        verbose_name = 'উপজেলা'
        verbose_name_plural = 'উপজেলা'

    def __str__(self):
        return f'{self.name}, {self.district.name}'
