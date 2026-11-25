from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    def create_user(self, phone=None, password=None, email=None, **extra):
        if not phone and not email:
            raise ValueError('মোবাইল নম্বর অথবা ইমেইল আবশ্যক')
        if email:
            email = self.normalize_email(email)
        user = self.model(phone=phone, email=email, **extra)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone=None, password=None, email=None, **extra):
        extra.setdefault('role', 'admin')
        extra.setdefault('is_staff', True)
        extra.setdefault('is_superuser', True)
        if not email and not phone:
            email = 'admin@moukhamar.com'
        return self.create_user(phone=phone, password=password, email=email, **extra)


class User(AbstractBaseUser, PermissionsMixin):
    """users — খামারি, কৃষক ও অ্যাডমিন সবাই এখানে।

    ভূমিকা-নির্দিষ্ট ঘরগুলো (খামারের নাম, অভিজ্ঞতা, প্রধান ফসল) আগে এই
    টেবিলেই ছিল — খামারির সারিতে `main_crop` খালি, কৃষকের সারিতে
    `farm_name` খালি পড়ে থাকত। এখন সেগুলো আলাদা 1:1 টেবিলে
    (farmer_profiles / cropper_profiles)।

    জেলা-উপজেলাও আর string নয় — upazila_id দিয়ে locations-এর সাথে জোড়া,
    জেলা উপজেলার মাধ্যমে পাওয়া যায়।
    """

    ROLE_CHOICES = [('farmer', 'খামারি'), ('cropper', 'কৃষক'), ('admin', 'অ্যাডমিন')]

    phone = models.CharField(max_length=15, unique=True, null=True, blank=True, verbose_name='মোবাইল নম্বর')
    email = models.EmailField(max_length=255, unique=True, null=True, blank=True, verbose_name='ইমেইল')
    name = models.CharField(max_length=100, verbose_name='নাম')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='farmer', verbose_name='ভূমিকা')
    upazila = models.ForeignKey('locations.Upazila', on_delete=models.SET_NULL, null=True, blank=True,
                               related_name='residents', verbose_name='উপজেলা')
    is_active = models.BooleanField(default=True, verbose_name='সক্রিয়')
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='নিবন্ধনের সময়')

    objects = UserManager()
    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = ['name']

    class Meta:
        db_table = 'users'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['role'], name='ix_user_role'),
            models.Index(fields=['upazila'], name='ix_user_upazila'),
        ]
        verbose_name = 'ব্যবহারকারী'
        verbose_name_plural = 'ব্যবহারকারী'

    def __str__(self):
        return f'{self.name} ({self.email or self.phone or self.id})'

    # সুবিধার জন্য — উপজেলার মধ্য দিয়ে জেলা
    @property
    def district(self):
        return self.upazila.district if self.upazila_id else None


class FarmerProfile(models.Model):
    """farmer_profiles — শুধু খামারির ঘরগুলো (1:1)।

    `rating` হিসেব করা মান নয়, অ্যাপে দেখানোর জন্য দেওয়া একটা মান —
    তাই কলাম হিসেবেই রাখা হলো। মোট মধু আর সক্রিয় বাক্স কলামে রাখা হয়নি,
    সেগুলো harvests ও hives থেকে ভিউতে গোনা হবে।
    """

    FARM_TYPE = [('স্থায়ী', 'স্থায়ী'), ('ভ্রাম্যমাণ', 'ভ্রাম্যমাণ')]

    user = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True,
                                related_name='farmer_profile', verbose_name='ব্যবহারকারী')
    farm_name = models.CharField(max_length=120, blank=True, verbose_name='খামারের নাম')
    farm_type = models.CharField(max_length=15, choices=FARM_TYPE, default='স্থায়ী', verbose_name='খামারের ধরন')
    experience_years = models.PositiveSmallIntegerField(default=0, verbose_name='অভিজ্ঞতা (বছর)')
    rating = models.DecimalField(max_digits=2, decimal_places=1, default=0, verbose_name='রেটিং')

    class Meta:
        db_table = 'farmer_profiles'
        verbose_name = 'খামারির তথ্য'
        verbose_name_plural = 'খামারির তথ্য'

    def __str__(self):
        return self.farm_name or self.user.name


class CropperProfile(models.Model):
    """cropper_profiles — শুধু কৃষকের ঘর (1:1)।"""

    user = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True,
                                related_name='cropper_profile', verbose_name='ব্যবহারকারী')
    main_crop = models.ForeignKey('reference.Crop', on_delete=models.SET_NULL, null=True, blank=True,
                                  related_name='croppers', verbose_name='প্রধান ফসল')

    class Meta:
        db_table = 'cropper_profiles'
        verbose_name = 'কৃষকের তথ্য'
        verbose_name_plural = 'কৃষকের তথ্য'

    def __str__(self):
        return self.user.name
