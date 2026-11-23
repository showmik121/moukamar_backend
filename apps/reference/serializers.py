import json
from rest_framework import serializers
from .models import Disease, Flora, Outbreak


class DiseaseSerializer(serializers.ModelSerializer):
    signs_list = serializers.SerializerMethodField()
    prevent_list = serializers.SerializerMethodField()
    treat_list = serializers.SerializerMethodField()

    class Meta:
        model = Disease
        fields = '__all__'

    def _parse(self, val):
        try:
            return json.loads(val)
        except Exception:
            return [val]

    def get_signs_list(self, obj):
        return self._parse(obj.signs)

    def get_prevent_list(self, obj):
        return self._parse(obj.prevent)

    def get_treat_list(self, obj):
        return self._parse(obj.treat)


class FloraSerializer(serializers.ModelSerializer):
    months_list = serializers.SerializerMethodField()

    class Meta:
        model = Flora
        fields = '__all__'

    def get_months_list(self, obj):
        try:
            return json.loads(obj.months)
        except Exception:
            return []


class OutbreakSerializer(serializers.ModelSerializer):
    class Meta:
        model = Outbreak
        fields = '__all__'
