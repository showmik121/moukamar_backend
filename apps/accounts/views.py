from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.contrib.auth import login, logout
from .serializers import RegisterSerializer, LoginSerializer, UserSerializer


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = RegisterSerializer(data=request.data)
        if ser.is_valid():
            user = ser.save()
            login(request, user, backend='apps.accounts.backends.PhoneOrEmailBackend')
            return Response({'user': UserSerializer(user).data}, status=201)
        return Response(ser.errors, status=400)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ser = LoginSerializer(data=request.data)
        if ser.is_valid():
            user = ser.validated_data['user']
            backend = getattr(user, 'backend', 'apps.accounts.backends.PhoneOrEmailBackend')
            login(request, user, backend=backend)
            return Response({'user': UserSerializer(user).data})
        return Response(ser.errors, status=400)


class LogoutView(APIView):
    def post(self, request):
        logout(request)
        return Response({'detail': 'লগ আউট সফল'})


class MeView(APIView):
    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        ser = UserSerializer(request.user, data=request.data, partial=True)
        if ser.is_valid():
            ser.save()
            return Response(ser.data)
        return Response(ser.errors, status=400)


class UserListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        from .models import User
        users = User.objects.all().order_by('-created_at')
        return Response(UserSerializer(users, many=True).data)

