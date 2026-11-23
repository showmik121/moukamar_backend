from django.db import models
from apps.accounts.models import User


class Notification(models.Model):
    KIND = [('spray', 'কীটনাশক স্প্রে'), ('disease', 'রোগের সতর্কতা'), ('other', 'অন্যান্য')]

    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications', verbose_name='প্রাপক')
    kind = models.CharField(max_length=15, choices=KIND, verbose_name='ধরন')
    title = models.CharField(max_length=200, verbose_name='শিরোনাম')
    body = models.TextField(verbose_name='বিবরণ')
    unread = models.BooleanField(default=True, verbose_name='অপঠিত')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-created_at']
        verbose_name = 'সতর্কতা'


class SprayAlert(models.Model):
    """কৃষক স্প্রে করার আগে দেওয়া নোটিশ"""
    cropper = models.ForeignKey(User, on_delete=models.CASCADE, related_name='spray_alerts', verbose_name='কৃষক')
    district = models.CharField(max_length=60, verbose_name='জেলা')
    upazila = models.CharField(max_length=60, verbose_name='উপজেলা')
    spray_date = models.DateField(verbose_name='স্প্রে তারিখ')
    spray_time = models.CharField(max_length=50, blank=True, verbose_name='সময়')
    crop = models.CharField(max_length=50, verbose_name='ফসল')
    chemical = models.CharField(max_length=100, blank=True, verbose_name='কীটনাশকের নাম')
    notes = models.TextField(blank=True, verbose_name='মন্তব্য')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'spray_alerts'
        ordering = ['-created_at']
        verbose_name = 'স্প্রে সতর্কতা'
