from django.contrib.auth.backends import ModelBackend
from django.db.models import Q
from .models import User


class PhoneOrEmailBackend(ModelBackend):
    """
    মোবাইল নম্বর অথবা ইমেইল — যেকোনো একটির সাহায্যে ব্যবহারকারী/অ্যাডমিন লগইন অনুমোদন করে।
    """
    def authenticate(self, request, username=None, password=None, **kwargs):
        ident = username or kwargs.get('phone') or kwargs.get('email')
        if not ident or not password:
            return None

        ident_str = str(ident).strip()
        cleaned_phone = ident_str.replace('-', '').replace(' ', '')

        user = User.objects.filter(
            Q(email__iexact=ident_str) | Q(phone=cleaned_phone)
        ).first()

        if user and user.check_password(password) and self.user_can_authenticate(user):
            return user
        return None
