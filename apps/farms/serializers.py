from rest_framework import serializers
from .models import Farm, Hive, Inspection, Harvest


class FarmSerializer(serializers.ModelSerializer):
    hive_count = serializers.SerializerMethodField()
    queenless_count = serializers.SerializerMethodField()

    class Meta:
        model = Farm
        fields = '__all__'
        read_only_fields = ['owner', 'created_at']

    def get_hive_count(self, obj):
        return obj.hives.count()

    def get_queenless_count(self, obj):
        return obj.hives.filter(queen='নেই').count()


class HiveSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hive
        fields = '__all__'
        read_only_fields = ['created_at']


class InspectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Inspection
        fields = '__all__'
        read_only_fields = ['inspector', 'created_at']


class HarvestSerializer(serializers.ModelSerializer):
    class Meta:
        model = Harvest
        fields = '__all__'
        read_only_fields = ['harvester', 'created_at']
