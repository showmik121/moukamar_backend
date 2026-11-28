from rest_framework.permissions import BasePermission


def is_app_admin(user):
    """অ্যাডমিন — role='admin' অথবা Django-র staff/superuser।"""
    return bool(user and user.is_authenticated
                and (user.role == 'admin' or user.is_staff or user.is_superuser))


class IsAppAdmin(BasePermission):
    """শুধু অ্যাডমিন ঢুকতে পারবেন।

    আগে /api/auth/users/ সবার জন্য খোলা ছিল — লগ ইন ছাড়াই যে কেউ সব
    ব্যবহারকারীর ফোন নম্বর ও ইমেইল দেখতে পেত।
    """

    message = 'এই পাতা শুধু অ্যাডমিনের জন্য'

    def has_permission(self, request, view):
        return is_app_admin(request.user)
