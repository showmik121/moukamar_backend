from django.db import models


class Tag(models.Model):
    """tags — পোস্টের ট্যাগ।

    আগে posts.tags কলামে "সরিষা, মধু, যন্ত্র" এভাবে কমা দিয়ে লেখা হতো —
    1NF ভাঙত, আর ট্যাগ ধরে খোঁজাও যেত না। এখন post_tags junction।
    """

    name = models.CharField(max_length=50, unique=True, verbose_name='ট্যাগ')

    class Meta:
        db_table = 'tags'
        ordering = ['name']
        verbose_name = 'ট্যাগ'
        verbose_name_plural = 'ট্যাগ'

    def __str__(self):
        return self.name


class Post(models.Model):
    """posts — কমিউনিটির পোস্ট (community.html)।

    upvote_count কলামটা রাখা হয়েছে শুধু দ্রুত পড়ার জন্য; আসল হিসাব
    post_votes টেবিলে। কলামটা trigger দিয়ে ঠিক রাখা হয়, হাতে নয় —
    তাই দুটো কখনো আলাদা হয়ে যায় না।
    """

    CATEGORY = [
        ('flora', 'ফুলের খবর'),
        ('resource', 'যন্ত্রপাতি ও সম্পদ'),
        ('qa', 'সমস্যা ও সমাধান'),
        ('tips', 'অভিজ্ঞতা ও পরামর্শ'),
    ]

    author = models.ForeignKey('accounts.User', on_delete=models.CASCADE,
                               related_name='posts', verbose_name='লেখক')
    category = models.CharField(max_length=15, choices=CATEGORY, verbose_name='বিভাগ')
    title = models.CharField(max_length=200, verbose_name='শিরোনাম')
    body = models.TextField(verbose_name='বিবরণ')
    resource_type = models.CharField(max_length=50, blank=True, verbose_name='সম্পদের ধরন')
    price = models.CharField(max_length=80, blank=True, verbose_name='মূল্য')
    upvote_count = models.PositiveIntegerField(default=0, verbose_name='উপভোট')
    tags = models.ManyToManyField(Tag, db_table='post_tags', blank=True,
                                  related_name='posts', verbose_name='ট্যাগ')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'posts'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['category', '-created_at'], name='ix_post_category_date'),
        ]
        verbose_name = 'পোস্ট'
        verbose_name_plural = 'পোস্ট'

    def __str__(self):
        return self.title


class PostVote(models.Model):
    """post_votes — একজন একটা পোস্টে একবারই upvote দিতে পারে (UNIQUE)।"""

    post = models.ForeignKey(Post, on_delete=models.CASCADE,
                             related_name='votes', verbose_name='পোস্ট')
    user = models.ForeignKey('accounts.User', on_delete=models.CASCADE,
                             related_name='post_votes', verbose_name='ব্যবহারকারী')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'post_votes'
        constraints = [
            models.UniqueConstraint(fields=['post', 'user'], name='uq_one_vote_per_user'),
        ]
        verbose_name = 'উপভোট'
        verbose_name_plural = 'উপভোট'

    def __str__(self):
        return f'{self.user_id} → {self.post_id}'


class Comment(models.Model):
    """comments — পোস্টের মন্তব্য।"""

    post = models.ForeignKey(Post, on_delete=models.CASCADE,
                             related_name='comments', verbose_name='পোস্ট')
    author = models.ForeignKey('accounts.User', on_delete=models.CASCADE,
                               related_name='comments', verbose_name='লেখক')
    text = models.TextField(verbose_name='মন্তব্য')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'comments'
        ordering = ['created_at']
        indexes = [models.Index(fields=['post', 'created_at'], name='ix_comment_post')]
        verbose_name = 'মন্তব্য'
        verbose_name_plural = 'মন্তব্য'

    def __str__(self):
        return self.text[:40]
