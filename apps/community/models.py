from django.db import models
from apps.accounts.models import User


class Post(models.Model):
    CATEGORY = [
        ('flora', 'ফুলের খবর'),
        ('resource', 'যন্ত্রপাতি ও সম্পদ'),
        ('qa', 'সমস্যা ও সমাধান'),
        ('tips', 'অভিজ্ঞতা ও পরামর্শ'),
    ]

    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='posts', verbose_name='লেখক')
    category = models.CharField(max_length=15, choices=CATEGORY, verbose_name='বিভাগ')
    title = models.CharField(max_length=200, verbose_name='শিরোনাম')
    body = models.TextField(verbose_name='বিবরণ')
    resource_type = models.CharField(max_length=50, blank=True, verbose_name='সম্পদের ধরন')
    price = models.CharField(max_length=80, blank=True, verbose_name='মূল্য')
    tags = models.CharField(max_length=200, blank=True, verbose_name='ট্যাগ (কমা দিয়ে)')
    upvotes = models.PositiveIntegerField(default=0, verbose_name='উপভোট')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'community_posts'
        ordering = ['-created_at']
        verbose_name = 'পোস্ট'

    def __str__(self):
        return self.title


class Comment(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments', verbose_name='পোস্ট')
    author = models.ForeignKey(User, on_delete=models.CASCADE, verbose_name='লেখক')
    text = models.TextField(verbose_name='মন্তব্য')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'community_comments'
        ordering = ['created_at']
        verbose_name = 'মন্তব্য'
