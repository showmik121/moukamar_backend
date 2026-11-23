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
    ROLE_CHOICES = [('farmer', 'খামারি'), ('cropper', 'কৃষক'), ('admin', 'অ্যাডমিন')]

    phone = models.CharField(max_length=15, unique=True, null=True, blank=True, verbose_name='মোবাইল নম্বর')
    email = models.EmailField(max_length=255, unique=True, null=True, blank=True, verbose_name='ইমেইল')
    name = models.CharField(max_length=100, verbose_name='নাম')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='farmer', verbose_name='ভূমিকা')
    district = models.CharField(max_length=60, blank=True, verbose_name='জেলা')
    upazila = models.CharField(max_length=60, blank=True, verbose_name='উপজেলা')
    # খামারির জন্য
    farm_name = models.CharField(max_length=120, blank=True, verbose_name='খামারের নাম')
    farm_type = models.CharField(max_length=20, blank=True, verbose_name='খামারের ধরন')
    experience = models.PositiveSmallIntegerField(default=0, verbose_name='অভিজ্ঞতা (বছর)')
    # কৃষকের জন্য
    main_crop = models.CharField(max_length=50, blank=True, verbose_name='প্রধান ফসল')
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()
    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = ['name']

    class Meta:
        db_table = 'users'
        verbose_name = 'ব্যবহারকারী'

    def __str__(self):
        ident = self.email or self.phone or str(self.id)
        return f'{self.name} ({ident})'
