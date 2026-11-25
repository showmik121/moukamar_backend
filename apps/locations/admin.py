from django.contrib import admin
from .models import District, Upazila


@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ('name', 'lat', 'lng')
    search_fields = ('name',)


@admin.register(Upazila)
class UpazilaAdmin(admin.ModelAdmin):
    list_display = ('name', 'district')
    list_filter = ('district',)
    search_fields = ('name', 'district__name')
