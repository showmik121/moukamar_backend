from django.contrib.auth import authenticate
from django.db import transaction
from rest_framework import serializers

from apps.locations.utils import district_point, resolve_upazila
from apps.reference.models import Crop

from .models import CropperProfile, FarmerProfile, User


class UserSerializer(serializers.ModelSerializer):
    """অ্যাপে যে আকারে ব্যবহারকারী যায়।

    জেলা-উপজেলা এখন আলাদা টেবিলে, আর খামারি/কৃষকের ঘরগুলো 1:1 profile
    টেবিলে — কিন্তু frontend যে নামগুলো চেনে (district, farm, exp, crop)
    সেগুলোই পাঠানো হয়, তাই অ্যাপের কোড বদলাতে হয়নি।
    """

    district = serializers.SerializerMethodField()
    upazila = serializers.SerializerMethodField()
    farm = serializers.SerializerMethodField()
    farm_name = serializers.SerializerMethodField()
    farm_type = serializers.SerializerMethodField()
    type = serializers.SerializerMethodField()
    exp = serializers.SerializerMethodField()
    experience = serializers.SerializerMethodField()
    rating = serializers.SerializerMethodField()
    crop = serializers.SerializerMethodField()
    main_crop = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'phone', 'email', 'name', 'role', 'district', 'upazila',
                  'farm', 'farm_name', 'farm_type', 'type', 'exp', 'experience',
                  'rating', 'crop', 'main_crop', 'is_staff', 'is_superuser']

    # ---- এলাকা ----
    def get_district(self, obj):
        return obj.upazila.district.name if obj.upazila_id else ''

    def get_upazila(self, obj):
        return obj.upazila.name if obj.upazila_id else ''

    # ---- খামারির ঘর ----
    @staticmethod
    def _farmer(obj):
        return getattr(obj, 'farmer_profile', None)

    def get_farm(self, obj):
        p = self._farmer(obj)
        return p.farm_name if p else ''

    get_farm_name = get_farm

    def get_farm_type(self, obj):
        p = self._farmer(obj)
        return p.farm_type if p else ''

    get_type = get_farm_type

    def get_exp(self, obj):
        p = self._farmer(obj)
        return p.experience_years if p else 0

    get_experience = get_exp

    def get_rating(self, obj):
        p = self._farmer(obj)
        return float(p.rating) if p else 0.0

    # ---- কৃষকের ঘর ----
    def get_crop(self, obj):
        p = getattr(obj, 'cropper_profile', None)
        return p.main_crop.name if p and p.main_crop_id else ''

    get_main_crop = get_crop


class RegisterSerializer(serializers.Serializer):
    """নিবন্ধন — ব্যবহারকারী, profile আর প্রথম খামার একসাথে তৈরি হয়।

    আগের কোডে খামার তৈরির অংশটা `except Exception: pass`-এ মোড়া ছিল আর
    ভেতরে ভুল field নাম ও একটা অস্তিত্বহীন import ছিল — তাই কোনো খামার
    তৈরি হতো না, অথচ কোনো ভুলও দেখা যেত না। এখন পুরোটা একটা
    transaction-এ, আর কিছু ভুল হলে নিবন্ধনও হবে না (সব বা কিছুই না)।
    """

    phone = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)
    name = serializers.CharField(max_length=100)
    password = serializers.CharField(write_only=True, min_length=6)
    password2 = serializers.CharField(write_only=True, required=False, allow_blank=True, default='')
    role = serializers.ChoiceField(choices=User.ROLE_CHOICES, default='farmer')
    district = serializers.CharField(required=False, allow_blank=True, default='')
    upazila = serializers.CharField(required=False, allow_blank=True, default='')
    # খামারি — frontend দুই নামেই পাঠায়, দুটোই নেওয়া হয়
    farm = serializers.CharField(required=False, allow_blank=True, default='')
    farm_name = serializers.CharField(required=False, allow_blank=True, default='')
    type = serializers.CharField(required=False, allow_blank=True, default='')
    farm_type = serializers.CharField(required=False, allow_blank=True, default='')
    exp = serializers.IntegerField(required=False, default=0)
    experience = serializers.IntegerField(required=False, default=0)
    # কৃষক
    crop = serializers.CharField(required=False, allow_blank=True, default='')
    main_crop = serializers.CharField(required=False, allow_blank=True, default='')

    def validate(self, data):
        if not data.get('phone') and not data.get('email'):
            raise serializers.ValidationError({'phone': 'মোবাইল নম্বর অথবা ইমেইল আবশ্যক'})
        pw2 = data.get('password2') or ''
        if pw2 and data['password'] != pw2:
            raise serializers.ValidationError({'password': 'দুই পাসওয়ার্ড মেলেনি'})

        phone = (data.get('phone') or '').replace('-', '').replace(' ', '')
        if phone and User.objects.filter(phone=phone).exists():
            raise serializers.ValidationError({'phone': 'এই নম্বর দিয়ে আগেই নিবন্ধন হয়েছে'})
        email = (data.get('email') or '').strip()
        if email and User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError({'email': 'এই ইমেইল দিয়ে আগেই নিবন্ধন হয়েছে'})

        data['phone'] = phone or None
        data['email'] = email or None

        # তালিকার বাইরের জেলা/উপজেলা নতুন করে তৈরি হয় না — আটকানো হয়
        if (data.get('district') or '').strip() and not resolve_upazila(
                data.get('district'), data.get('upazila')):
            raise serializers.ValidationError({'upazila': 'জেলা বা উপজেলার নাম তালিকায় নেই'})
        return data

    @transaction.atomic
    def create(self, validated):
        from apps.farms.models import Farm

        district_name = validated.get('district', '')
        upazila = resolve_upazila(district_name, validated.get('upazila', ''))

        user = User.objects.create_user(
            phone=validated['phone'],
            email=validated['email'],
            password=validated['password'],
            name=validated['name'].strip(),
            role=validated.get('role', 'farmer'),
            upazila=upazila,
        )

        if user.role == 'farmer':
            farm_name = (validated.get('farm') or validated.get('farm_name') or '').strip()
            farm_type = (validated.get('type') or validated.get('farm_type') or '').strip() or 'স্থায়ী'
            if farm_type not in dict(FarmerProfile.FARM_TYPE):
                farm_type = 'স্থায়ী'
            FarmerProfile.objects.create(
                user=user,
                farm_name=farm_name,
                farm_type=farm_type,
                experience_years=validated.get('exp') or validated.get('experience') or 0,
            )
            # প্রথম খামার — অবস্থান জেলার coordinate থেকে
            if upazila:
                lat, lng = district_point(district_name)
                Farm.objects.create(
                    owner=user,
                    name=farm_name or f'{user.name}-এর খামার',
                    upazila=upazila,
                    farm_type=farm_type,
                    status='সক্রিয়',
                    lat=lat,
                    lng=lng,
                )

        elif user.role == 'cropper':
            crop_name = (validated.get('crop') or validated.get('main_crop') or '').strip()
            crop = Crop.objects.get_or_create(name=crop_name)[0] if crop_name else None
            CropperProfile.objects.create(user=user, main_crop=crop)

        return user


class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField(required=False, allow_blank=True, default='')
    email = serializers.CharField(required=False, allow_blank=True, default='')
    password = serializers.CharField()

    def validate(self, data):
        identifier = (data.get('email') or '').strip() or (data.get('phone') or '').strip()
        if not identifier:
            raise serializers.ValidationError('মোবাইল নম্বর অথবা ইমেইল দিন')

        user = authenticate(username=identifier, password=data.get('password', ''))
        if not user:
            if '@' in identifier:
                raise serializers.ValidationError('ইমেইল বা পাসওয়ার্ড ভুল হয়েছে')
            raise serializers.ValidationError('মোবাইল নম্বর বা পাসওয়ার্ড ভুল')
        if not user.is_active:
            raise serializers.ValidationError('অ্যাকাউন্ট নিষ্ক্রিয় করা হয়েছে')

        data['user'] = user
        return data


class ProfileUpdateSerializer(serializers.Serializer):
    """PATCH /api/auth/me/ — প্রোফাইল আপডেট।

    district/upazila নাম দিয়ে আসে, এখানে id-তে রূপান্তর হয়।
    """

    name = serializers.CharField(required=False)
    phone = serializers.CharField(required=False, allow_blank=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    district = serializers.CharField(required=False, allow_blank=True)
    upazila = serializers.CharField(required=False, allow_blank=True)
    farm = serializers.CharField(required=False, allow_blank=True)
    farm_name = serializers.CharField(required=False, allow_blank=True)
    type = serializers.CharField(required=False, allow_blank=True)
    farm_type = serializers.CharField(required=False, allow_blank=True)
    exp = serializers.IntegerField(required=False)
    experience = serializers.IntegerField(required=False)
    crop = serializers.CharField(required=False, allow_blank=True)
    main_crop = serializers.CharField(required=False, allow_blank=True)

    @transaction.atomic
    def update(self, user, validated):
        if 'name' in validated:
            user.name = validated['name'].strip()
        if validated.get('phone'):
            phone = validated['phone'].replace('-', '').replace(' ', '')
            if User.objects.filter(phone=phone).exclude(pk=user.pk).exists():
                raise serializers.ValidationError({'phone': 'এই নম্বর অন্য কেউ ব্যবহার করছেন'})
            user.phone = phone
        if validated.get('email'):
            email = validated['email'].strip()
            if User.objects.filter(email__iexact=email).exclude(pk=user.pk).exists():
                raise serializers.ValidationError({'email': 'এই ইমেইল অন্য কেউ ব্যবহার করছেন'})
            user.email = email

        if validated.get('district') or validated.get('upazila'):
            district_name = validated.get('district') or (
                user.upazila.district.name if user.upazila_id else '')
            upazila_name = validated.get('upazila') or (
                user.upazila.name if user.upazila_id else '')
            upazila = resolve_upazila(district_name, upazila_name)
            if not upazila:
                raise serializers.ValidationError({'upazila': 'জেলা বা উপজেলার নাম তালিকায় নেই'})
            user.upazila = upazila
        user.save()

        if user.role == 'farmer':
            profile, _ = FarmerProfile.objects.get_or_create(user=user)
            farm_name = validated.get('farm') or validated.get('farm_name')
            farm_type = validated.get('type') or validated.get('farm_type')
            if farm_name:
                profile.farm_name = farm_name.strip()
            if farm_type and farm_type in dict(FarmerProfile.FARM_TYPE):
                profile.farm_type = farm_type
            exp = validated.get('exp', validated.get('experience'))
            if exp is not None:
                profile.experience_years = exp
            profile.save()

        elif user.role == 'cropper':
            profile, _ = CropperProfile.objects.get_or_create(user=user)
            crop_name = (validated.get('crop') or validated.get('main_crop') or '').strip()
            if crop_name:
                profile.main_crop = Crop.objects.get_or_create(name=crop_name)[0]
                profile.save()

        return user


class PasswordChangeSerializer(serializers.Serializer):
    """POST /api/auth/password/ — এই endpoint-টা আগে ছিল না, অথচ
    profile.html এখানেই পাসওয়ার্ড বদলের অনুরোধ পাঠাত (৪০৪ পেত)।"""

    old_password = serializers.CharField()
    new_password = serializers.CharField(min_length=6)

    def validate_old_password(self, value):
        if not self.context['request'].user.check_password(value):
            raise serializers.ValidationError('পুরনো পাসওয়ার্ড ভুল')
        return value

    def save(self, **kwargs):
        user = self.context['request'].user
        user.set_password(self.validated_data['new_password'])
        user.save(update_fields=['password'])
        return user
