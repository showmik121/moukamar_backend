from django.contrib.auth import login, logout
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import User
from .serializers import (LoginSerializer, PasswordChangeSerializer, ProfileUpdateSerializer,
                          RegisterSerializer, UserSerializer)

BACKEND = 'apps.accounts.backends.PhoneOrEmailBackend'


def _with_profiles(queryset):
    return queryset.select_related('upazila__district', 'farmer_profile',
                                   'cropper_profile__main_crop')


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = RegisterSerializer(data=request.data)
        if not ser.is_valid():
            return Response(ser.errors, status=400)
        user = ser.save()
        login(request, user, backend=BACKEND)
        return Response({'user': UserSerializer(user).data}, status=201)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = LoginSerializer(data=request.data)
        if not ser.is_valid():
            return Response(ser.errors, status=400)
        user = ser.validated_data['user']
        login(request, user, backend=getattr(user, 'backend', BACKEND))
        return Response({'user': UserSerializer(user).data})


class LogoutView(APIView):
    def post(self, request):
        logout(request)
        return Response({'detail': 'লগ আউট সফল'})


class MeView(APIView):
    def get(self, request):
        user = _with_profiles(User.objects.filter(pk=request.user.pk)).first()
        return Response(UserSerializer(user).data)

    def patch(self, request):
        ser = ProfileUpdateSerializer(data=request.data, partial=True)
        if not ser.is_valid():
            return Response(ser.errors, status=400)
        user = ser.update(request.user, ser.validated_data)
        user = _with_profiles(User.objects.filter(pk=user.pk)).first()
        return Response(UserSerializer(user).data)


class PasswordChangeView(APIView):
    def post(self, request):
        ser = PasswordChangeSerializer(data=request.data, context={'request': request})
        if not ser.is_valid():
            return Response(ser.errors, status=400)
        ser.save()
        # পাসওয়ার্ড বদলের পর session টিকিয়ে রাখা হয়, যাতে আবার লগ ইন করতে না হয়
        login(request, request.user, backend=BACKEND)
        return Response({'detail': 'পাসওয়ার্ড বদল হয়েছে'})


class UserListView(APIView):
    """GET /api/auth/users/ — অ্যাডমিন প্যানেলের ব্যবহারকারী তালিকা।"""

    permission_classes = [AllowAny]

    def get(self, request):
        users = _with_profiles(User.objects.all())
        return Response(UserSerializer(users, many=True).data)
