from django.utils import timezone
from rest_framework import serializers

from apps.common import bn_date
from apps.locations.utils import resolve_upazila
from apps.reference.models import BeeSpecies, Flora

from .models import Farm, Harvest, Hive, HiveEvent, Inspection, InspectionDisease, Queen


class FarmSerializer(serializers.ModelSerializer):
    """frontend-এর FARMS যে আকার চায় (district/upazila/flora নামে), সেই আকার।"""

    district = serializers.CharField(source='upazila.district.name', read_only=True)
    upazila_name = serializers.CharField(source='upazila.name', read_only=True)
    upazila = serializers.CharField(write_only=True, required=False, allow_blank=True)
    district_name = serializers.CharField(write_only=True, required=False, allow_blank=True)
    flora = serializers.SerializerMethodField()
    flora_names = serializers.ListField(child=serializers.CharField(), write_only=True,
                                        required=False)
    since = serializers.SerializerMethodField()
    hive_count = serializers.SerializerMethodField()
    queenless_count = serializers.SerializerMethodField()

    class Meta:
        model = Farm
        fields = ['id', 'name', 'district', 'upazila', 'upazila_name', 'district_name',
                  'farm_type', 'status', 'established_on', 'since', 'lat', 'lng',
                  'flora', 'flora_names', 'hive_count', 'queenless_count']

    def get_flora(self, obj):
        return [f.name for f in obj.flora.all()]

    def get_since(self, obj):
        return bn_date(obj.established_on) or 'স্থায়ী'

    def get_hive_count(self, obj):
        return obj.hives.count()

    def get_queenless_count(self, obj):
        return obj.hives.filter(state='রানীহীন').count()

    def _apply_location(self, validated):
        district_name = validated.pop('district_name', '')
        upazila_name = validated.pop('upazila', '')
        if upazila_name or district_name:
            upazila = resolve_upazila(district_name, upazila_name)
            if upazila:
                validated['upazila'] = upazila
        return validated

    def _apply_flora(self, farm, names):
        if names is None:
            return
        farm.flora.set([Flora.objects.get_or_create(name=n.strip())[0]
                        for n in names if n and n.strip()])

    def create(self, validated):
        names = validated.pop('flora_names', None)
        validated = self._apply_location(validated)
        farm = Farm.objects.create(**validated)
        self._apply_flora(farm, names)
        return farm

    def update(self, farm, validated):
        names = validated.pop('flora_names', None)
        validated = self._apply_location(validated)
        for key, value in validated.items():
            setattr(farm, key, value)
        farm.save()
        self._apply_flora(farm, names)
        return farm


class HiveSerializer(serializers.ModelSerializer):
    """বাক্সের তথ্য — রানী ও শেষ পরিদর্শন দুটোই এখন আলাদা টেবিল থেকে আসে।

    `queen`, `queenAge` আর `last` আগে hives টেবিলের কলাম ছিল। এখন:
      queen/queenAge  → queens টেবিলের চলতি সারি থেকে
      last            → শেষ পরিদর্শনের তারিখ থেকে দিন গুনে
    তাই সংখ্যাগুলো আর কখনো পুরনো হয়ে থাকে না।
    """

    species_name = serializers.CharField(source='species.name', read_only=True)
    species = serializers.CharField(write_only=True, required=False)
    farm_name = serializers.CharField(source='farm.name', read_only=True)
    queen = serializers.SerializerMethodField()
    queenAge = serializers.SerializerMethodField()
    last = serializers.SerializerMethodField()

    class Meta:
        model = Hive
        fields = ['id', 'code', 'farm', 'farm_name', 'species', 'species_name',
                  'frames', 'filled', 'state', 'installed_on',
                  'queen', 'queenAge', 'last']

    def get_queen(self, obj):
        return 'আছে' if obj.current_queen else 'নেই'

    def get_queenAge(self, obj):
        queen = obj.current_queen
        if not queen:
            return 0
        days = (timezone.localdate() - queen.installed_on).days
        return max(days // 365, 0)

    def get_last(self, obj):
        latest = obj.inspections.first()
        if not latest:
            return None
        return (timezone.localdate() - latest.inspect_date).days

    def _species(self, validated):
        name = validated.pop('species', None)
        if name:
            validated['species'] = BeeSpecies.objects.get_or_create(name=name.strip())[0]
        return validated

    def create(self, validated):
        return Hive.objects.create(**self._species(validated))

    def update(self, hive, validated):
        for key, value in self._species(validated).items():
            setattr(hive, key, value)
        hive.save()
        return hive


class QueenSerializer(serializers.ModelSerializer):
    class Meta:
        model = Queen
        fields = ['id', 'hive', 'source', 'color_mark', 'installed_on', 'removed_on', 'note']
        read_only_fields = ['removed_on']


class HiveEventSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.name', read_only=True)
    date = serializers.DateField(source='event_date')

    class Meta:
        model = HiveEvent
        fields = ['id', 'hive', 'date', 'kind', 'note', 'actor', 'actor_name']
        read_only_fields = ['actor']


class InspectionSerializer(serializers.ModelSerializer):
    date = serializers.DateField(source='inspect_date')
    hive_code = serializers.CharField(source='hive.code', read_only=True)
    inspector_name = serializers.CharField(source='inspector.name', read_only=True)
    diseases = serializers.SerializerMethodField()
    disease_codes = serializers.ListField(child=serializers.CharField(), write_only=True,
                                          required=False)

    class Meta:
        model = Inspection
        fields = ['id', 'hive', 'hive_code', 'date', 'frames_filled', 'state',
                  'queen_seen', 'eggs_seen', 'notes', 'inspector', 'inspector_name',
                  'diseases', 'disease_codes']
        read_only_fields = ['inspector']

    def get_diseases(self, obj):
        return [{'code': d.disease.code, 'name': d.disease.name, 'severity': d.severity}
                for d in InspectionDisease.objects.filter(inspection=obj).select_related('disease')]


class HarvestSerializer(serializers.ModelSerializer):
    date = serializers.DateField(source='harvest_date')
    hive_code = serializers.CharField(source='hive.code', read_only=True)
    flora_name = serializers.CharField(source='flora.name', read_only=True)
    harvester_name = serializers.CharField(source='harvester.name', read_only=True)

    class Meta:
        model = Harvest
        fields = ['id', 'hive', 'hive_code', 'date', 'kg', 'moisture',
                  'flora', 'flora_name', 'notes', 'harvester', 'harvester_name']
        read_only_fields = ['harvester']
