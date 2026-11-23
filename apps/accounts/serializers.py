from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    password2 = serializers.CharField(write_only=True, required=False, allow_blank=True, default='')
    phone = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)
    farm = serializers.CharField(required=False, allow_blank=True, write_only=True)
    type = serializers.CharField(required=False, allow_blank=True, write_only=True)
    exp = serializers.IntegerField(required=False, write_only=True)
    crop = serializers.CharField(required=False, allow_blank=True, write_only=True)

    class Meta:
        model = User
        fields = ['phone', 'email', 'password', 'password2', 'name', 'role',
                  'district', 'upazila', 'farm_name', 'farm_type', 'experience', 'main_crop',
                  'farm', 'type', 'exp', 'crop']

    def validate(self, data):
        if not data.get('phone') and not data.get('email'):
            raise serializers.ValidationError({'phone': 'মোবাইল নম্বর অথবা ইমেইল আবশ্যক'})
        pw2 = data.pop('password2', '')
        if pw2 and data['password'] != pw2:
            raise serializers.ValidationError({'password': 'দুই পাসওয়ার্ড মেলেনি'})
        return data

    def create(self, validated_data):
        farm = validated_data.pop('farm', None)
        farm_type = validated_data.pop('type', None)
        exp = validated_data.pop('exp', None)
        crop = validated_data.pop('crop', None)

        if farm and not validated_data.get('farm_name'):
            validated_data['farm_name'] = farm
        if farm_type and not validated_data.get('farm_type'):
            validated_data['farm_type'] = farm_type
        if exp is not None and not validated_data.get('experience'):
            validated_data['experience'] = exp
        if crop and not validated_data.get('main_crop'):
            validated_data['main_crop'] = crop

        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()

        # যদি খামারি হয়, সরাসরি ফার্ম তৈরি করা
        if user.role == 'farmer':
            try:
                from apps.farms.models import Farm
                from apps.reference.views import DISTRICT_COORDS
                farm_title = user.farm_name or f"{user.name}-এর খামার"
                lat, lng = 24.0, 89.8
                if user.district and user.district in DISTRICT_COORDS:
                    lat, lng = DISTRICT_COORDS[user.district]
                Farm.objects.create(
                    owner=user,
                    name=farm_title,
                    district=user.district or '',
                    upazila=user.upazila or '',
                    farm_type=user.farm_type or 'স্থায়ী',
                    latitude=lat,
                    longitude=lng,
                    status='active'
                )
            except Exception:
                pass

        return user


class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField(required=False, allow_blank=True, default='')
    email = serializers.CharField(required=False, allow_blank=True, default='')
    password = serializers.CharField()

    def validate(self, data):
        phone = data.get('phone', '').strip()
        email = data.get('email', '').strip()
        password = data.get('password', '')

        identifier = email or phone
        if not identifier:
            raise serializers.ValidationError('মোবাইল নম্বর অথবা ইমেইল দিন')

        user = authenticate(username=identifier, password=password)
        if not user:
            if '@' in identifier:
                raise serializers.ValidationError('ইমেইল বা পাসওয়ার্ড ভুল হয়েছে')
            raise serializers.ValidationError('মোবাইল নম্বর বা পাসওয়ার্ড ভুল')
        if not user.is_active:
            raise serializers.ValidationError('অ্যাকাউন্ট নিষ্ক্রিয় করা হয়েছে')
        data['user'] = user
        return data


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'phone', 'email', 'name', 'role', 'district', 'upazila',
                  'farm_name', 'farm_type', 'experience', 'main_crop', 'is_staff', 'is_superuser']
