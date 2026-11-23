from django.contrib import admin
from .models import Farm, Hive, Inspection, Harvest

@admin.register(Farm)
class FarmAdmin(admin.ModelAdmin):
    list_display = ['name', 'owner', 'district', 'upazila', 'status']
    list_filter = ['status', 'district']

@admin.register(Hive)
class HiveAdmin(admin.ModelAdmin):
    list_display = ['code', 'farm', 'state', 'queen', 'frames']
    list_filter = ['state', 'queen']

@admin.register(Inspection)
class InspectionAdmin(admin.ModelAdmin):
    list_display = ['hive', 'date', 'state', 'queen_seen']

@admin.register(Harvest)
class HarvestAdmin(admin.ModelAdmin):
    list_display = ['hive', 'date', 'kg', 'flora']
