from django.contrib import admin
from .models import Farm, Hive, Queen, HiveEvent, Inspection, InspectionDisease, Harvest


@admin.register(Farm)
class FarmAdmin(admin.ModelAdmin):
    list_display = ['name', 'owner', 'upazila', 'farm_type', 'status']
    list_filter = ['status', 'farm_type']
    search_fields = ['name', 'owner__name']
    filter_horizontal = ['flora']


@admin.register(Hive)
class HiveAdmin(admin.ModelAdmin):
    list_display = ['code', 'farm', 'species', 'state', 'frames', 'filled']
    list_filter = ['state', 'species']
    search_fields = ['code']


@admin.register(Queen)
class QueenAdmin(admin.ModelAdmin):
    list_display = ['hive', 'installed_on', 'removed_on', 'color_mark']
    list_filter = ['removed_on']


@admin.register(HiveEvent)
class HiveEventAdmin(admin.ModelAdmin):
    list_display = ['hive', 'event_date', 'kind', 'note']
    list_filter = ['kind']


class InspectionDiseaseInline(admin.TabularInline):
    model = InspectionDisease
    extra = 1


@admin.register(Inspection)
class InspectionAdmin(admin.ModelAdmin):
    inlines = [InspectionDiseaseInline]
    list_display = ['hive', 'inspect_date', 'state', 'queen_seen', 'frames_filled']
    list_filter = ['state', 'queen_seen']


@admin.register(Harvest)
class HarvestAdmin(admin.ModelAdmin):
    list_display = ['hive', 'harvest_date', 'kg', 'moisture', 'flora']
    list_filter = ['flora']
