from django.db import models


class AuditLog(models.Model):
    """audit_log — কোন সারি কে কখন বদলাল তার হিসাব।

    এই টেবিলে Python থেকে কিছু লেখা হয় না — sql/08_triggers.sql-এর
    TRIGGER গুলো hives ও harvests টেবিলের UPDATE/DELETE ধরে নিজে ভরে।
    তাই অ্যাপ বাইপাস করে কেউ সরাসরি SQL দিয়ে বদলালেও হিসাব থেকে যায়।
    """

    ACTION = [('INSERT', 'যোগ'), ('UPDATE', 'বদল'), ('DELETE', 'মোছা')]

    table_name = models.CharField(max_length=64, verbose_name='টেবিল')
    row_pk = models.BigIntegerField(verbose_name='সারির আইডি')
    action = models.CharField(max_length=6, choices=ACTION, verbose_name='কাজ')
    actor = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True,
                              related_name='audit_entries', verbose_name='কে')
    old_data = models.JSONField(null=True, blank=True, verbose_name='আগের মান')
    new_data = models.JSONField(null=True, blank=True, verbose_name='নতুন মান')
    changed_at = models.DateTimeField(auto_now_add=True, verbose_name='কখন')

    class Meta:
        db_table = 'audit_log'
        ordering = ['-changed_at']
        indexes = [
            models.Index(fields=['table_name', 'row_pk'], name='ix_audit_row'),
            models.Index(fields=['-changed_at'], name='ix_audit_time'),
        ]
        verbose_name = 'নিরীক্ষার হিসাব'
        verbose_name_plural = 'নিরীক্ষার হিসাব'

    def __str__(self):
        return f'{self.table_name}#{self.row_pk} — {self.action}'
