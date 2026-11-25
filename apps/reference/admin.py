from django.contrib import admin
from .models import Month, Crop, BeeSpecies, Flora, Symptom, Disease, DiseaseStep


@admin.register(Month)
class MonthAdmin(admin.ModelAdmin):
    list_display = ['month_no', 'name_bn']


@admin.register(Crop)
class CropAdmin(admin.ModelAdmin):
    list_display = ['name']
    search_fields = ['name']


@admin.register(BeeSpecies)
class BeeSpeciesAdmin(admin.ModelAdmin):
    list_display = ['name', 'sci_name']


@admin.register(Flora)
class FloraAdmin(admin.ModelAdmin):
    list_display = ['name', 'where_found', 'is_dearth']
    filter_horizontal = ['blooms']


@admin.register(Symptom)
class SymptomAdmin(admin.ModelAdmin):
    list_display = ['code', 'name']
    search_fields = ['name']


class DiseaseStepInline(admin.TabularInline):
    model = DiseaseStep
    extra = 1


@admin.register(Disease)
class DiseaseAdmin(admin.ModelAdmin):
    inlines = [DiseaseStepInline]
    list_display = ['name', 'kind', 'risk']
    list_filter = ['risk', 'kind']
    filter_horizontal = ['symptoms']
