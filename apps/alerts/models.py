from django.db import models


class SprayAlert(models.Model):
    """spray_alerts — কৃষক কীটনাশক ছিটানোর আগে যে নোটিশ দেন (alerts.html)।

    এই টেবিলে একটা সারি ঢুকলেই ওই উপজেলার সব খামারির জন্য notifications
    তৈরি হয়। আগে কাজটা Python লুপে হতো; এখন sql/08_triggers.sql-এর
    AFTER INSERT trigger করে — তাই সরাসরি SQL দিয়ে নোটিশ ঢোকালেও
    খামারিরা জানতে পারেন।
    """

    cropper = models.ForeignKey('accounts.User', on_delete=models.CASCADE,
                                related_name='spray_alerts', verbose_name='কৃষক')
    upazila = models.ForeignKey('locations.Upazila', on_delete=models.PROTECT,
                                related_name='spray_alerts', verbose_name='উপজেলা')
    crop = models.ForeignKey('reference.Crop', on_delete=models.PROTECT,
                             related_name='spray_alerts', verbose_name='ফসল')
    spray_date = models.DateField(verbose_name='স্প্রের তারিখ')
    spray_time = models.CharField(max_length=50, blank=True, verbose_name='সময়')
    chemical = models.CharField(max_length=100, blank=True, verbose_name='কীটনাশকের নাম')
    notes = models.TextField(blank=True, verbose_name='মন্তব্য')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'spray_alerts'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['upazila', '-spray_date'], name='ix_spray_upazila_date'),
        ]
        verbose_name = 'স্প্রে সতর্কতা'
        verbose_name_plural = 'স্প্রে সতর্কতা'

    def __str__(self):
        return f'{self.upazila} — {self.spray_date}'


class Notification(models.Model):
    """notifications — ব্যবহারকারীর কাছে যাওয়া সতর্কতা ও খবর।

    ref_table + ref_id দিয়ে বোঝা যায় খবরটা কোন সারি থেকে এসেছে
    (spray_alerts, inspections ইত্যাদি) — trigger এগুলো ভরে দেয়।
    """

    KIND = [('spray', 'কীটনাশক স্প্রে'), ('disease', 'রোগের সতর্কতা'),
            ('inspection', 'পরিদর্শন'), ('other', 'অন্যান্য')]

    recipient = models.ForeignKey('accounts.User', on_delete=models.CASCADE,
                                  related_name='notifications', verbose_name='প্রাপক')
    kind = models.CharField(max_length=15, choices=KIND, verbose_name='ধরন')
    title = models.CharField(max_length=200, verbose_name='শিরোনাম')
    body = models.TextField(verbose_name='বিবরণ')
    ref_table = models.CharField(max_length=64, blank=True, verbose_name='কোন টেবিল থেকে')
    ref_id = models.BigIntegerField(null=True, blank=True, verbose_name='কোন সারি')
    unread = models.BooleanField(default=True, verbose_name='অপঠিত')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient', 'unread'], name='ix_notif_recipient_unread'),
        ]
        verbose_name = 'সতর্কতা'
        verbose_name_plural = 'সতর্কতা'

    def __str__(self):
        return self.title
