from rest_framework import serializers

from .models import BeeSpecies, Crop, Disease, DiseaseStep, Flora, Month, Symptom


class SymptomSerializer(serializers.ModelSerializer):
    class Meta:
        model = Symptom
        fields = ['code', 'name']


class DiseaseSerializer(serializers.ModelSerializer):
    """frontend-এর data.js যে আকারে রোগ আশা করে, হুবহু সেই আকার।

    signs / prevent / treat আগে ডাটাবেজে JSON string হিসেবে পড়ে থাকত।
    এখন disease_steps টেবিল থেকে ক্রম মেনে তালিকা বানানো হয় — ডাটাবেজ
    normalized, অথচ অ্যাপের কোড বদলাতে হচ্ছে না।
    """

    id = serializers.CharField(source='code')
    symptoms = serializers.SerializerMethodField()
    signs = serializers.SerializerMethodField()
    prevent = serializers.SerializerMethodField()
    treat = serializers.SerializerMethodField()

    class Meta:
        model = Disease
        fields = ['id', 'name', 'kind', 'risk', 'cause', 'spread',
                  'symptoms', 'signs', 'prevent', 'treat']

    def get_symptoms(self, obj):
        return [s.code for s in obj.symptoms.all()]

    def _steps(self, obj, kind):
        return [s.text for s in obj.steps.all() if s.kind == kind]

    def get_signs(self, obj):
        return self._steps(obj, 'sign')

    def get_prevent(self, obj):
        return self._steps(obj, 'prevent')

    def get_treat(self, obj):
        return self._steps(obj, 'treat')


class FloraSerializer(serializers.ModelSerializer):
    where = serializers.CharField(source='where_found')
    months = serializers.SerializerMethodField()
    dearth = serializers.BooleanField(source='is_dearth')

    class Meta:
        model = Flora
        fields = ['id', 'name', 'where', 'months', 'dearth']

    def get_months(self, obj):
        return sorted(m.month_no for m in obj.blooms.all())


class MonthSerializer(serializers.ModelSerializer):
    class Meta:
        model = Month
        fields = ['month_no', 'name_bn']


class CropSerializer(serializers.ModelSerializer):
    class Meta:
        model = Crop
        fields = ['id', 'name']


class BeeSpeciesSerializer(serializers.ModelSerializer):
    class Meta:
        model = BeeSpecies
        fields = ['id', 'name', 'sci_name', 'note']


class DiseaseStepSerializer(serializers.ModelSerializer):
    class Meta:
        model = DiseaseStep
        fields = ['id', 'disease', 'kind', 'step_no', 'text']
