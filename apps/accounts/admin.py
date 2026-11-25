from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, FarmerProfile, CropperProfile


class FarmerInline(admin.StackedInline):
    model = FarmerProfile
    can_delete = False
    verbose_name_plural = 'খামারির তথ্য'


class CropperInline(admin.StackedInline):
    model = CropperProfile
    can_delete = False
    verbose_name_plural = 'কৃষকের তথ্য'


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    inlines = [FarmerInline, CropperInline]
    list_display = ['name', 'phone', 'email', 'role', 'upazila']
    list_filter = ['role', 'is_active']
    search_fields = ['phone', 'email', 'name']
    ordering = ['-created_at']
    fieldsets = (
        (None, {'fields': ('phone', 'email', 'password')}),
        ('ব্যক্তিগত তথ্য', {'fields': ('name', 'role', 'upazila')}),
        ('অনুমতি', {'fields': ('is_active', 'is_staff', 'is_superuser')}),
    )
    add_fieldsets = (
        (None, {'classes': ('wide',), 'fields': ('phone', 'email', 'name', 'role', 'password1', 'password2')}),
    )
