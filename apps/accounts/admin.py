from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['phone', 'name', 'role', 'district']
    list_filter = ['role', 'is_active']
    search_fields = ['phone', 'name']
    ordering = ['-created_at']
    fieldsets = (
        (None, {'fields': ('phone', 'password')}),
        ('ব্যক্তিগত তথ্য', {'fields': ('name', 'role', 'district', 'upazila')}),
        ('খামারি তথ্য', {'fields': ('farm_name', 'farm_type', 'experience')}),
        ('কৃষক তথ্য', {'fields': ('main_crop',)}),
        ('অনুমতি', {'fields': ('is_active', 'is_staff', 'is_superuser')}),
    )
    add_fieldsets = (
        (None, {'classes': ('wide',), 'fields': ('phone', 'name', 'role', 'password1', 'password2')}),
    )
