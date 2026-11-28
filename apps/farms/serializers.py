from django.utils import timezone
from rest_framework import serializers

from apps.common import bn_date
from apps.locations.utils import district_point, resolve_upazila

# sql/02_constraints.sql-এর chk_farm_point_in_bd-এর একই সীমা — আগে এখানে
# না দেখায় বাংলাদেশের বাইরের বিন্দু দিলে CHECK ভেঙে ৫০০ আসত
BD_LAT = (20.5, 26.7)
BD_LNG = (88.0, 92.7)
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
        return bn_date(obj.established_on) or '—'

    # .all() prefetch করা তালিকা থেকে পড়ে; .filter() দিলে প্রতিটা খামারে
    # আলাদা query যেত (N+1)
    def get_hive_count(self, obj):
        return len(obj.hives.all())

    def get_queenless_count(self, obj):
        return sum(1 for h in obj.hives.all() if h.state == 'রানীহীন')

    def validate(self, data):
        # নতুন খামারে জেলা লাগবেই — নাহলে upazila খালি থেকে ডাটাবেজ ৫০০ দিত
        if self.instance is None and not (data.get('district_name') or '').strip():
            raise serializers.ValidationError({'district_name': 'খামারের জেলা দিন'})

        lat = data.get('lat', getattr(self.instance, 'lat', None))
        lng = data.get('lng', getattr(self.instance, 'lng', None))
        if (lat is None) != (lng is None):
            raise serializers.ValidationError({'lat': 'অক্ষাংশ ও দ্রাঘিমাংশ দুটোই দিন'})
        if lat is not None and not (BD_LAT[0] <= float(lat) <= BD_LAT[1]
                                    and BD_LNG[0] <= float(lng) <= BD_LNG[1]):
            raise serializers.ValidationError({'lat': 'অবস্থানটা বাংলাদেশের ভেতরে হতে হবে'})
        return data

    def _apply_location(self, validated, farm=None):
        district_name = (validated.pop('district_name', '') or '').strip()
        upazila_name = (validated.pop('upazila', '') or '').strip()
        if upazila_name or district_name:
            # শুধু উপজেলা বদলালে জেলা আগের খামারেরটাই
            if not district_name and farm is not None and farm.upazila_id:
                district_name = farm.upazila.district.name
            upazila = resolve_upazila(district_name, upazila_name)
            if not upazila:
                raise serializers.ValidationError({'upazila': 'জেলা বা উপজেলার নাম তালিকায় নেই'})
            validated['upazila'] = upazila
        return validated

    def _apply_flora(self, farm, names):
        if names is None:
            return
        farm.flora.set([Flora.objects.get_or_create(name=n.strip())[0]
                        for n in names if n and n.strip()])

    def create(self, validated):
        names = validated.pop('flora_names', None)
        district_name = validated.get('district_name', '')
        validated = self._apply_location(validated)
        # অবস্থান না দিলে জেলার কেন্দ্র — নিবন্ধনের প্রথম খামারের মতো, যাতে
        # নতুন খামারও ম্যাপে দেখা যায় (আগে lat/lng ফাঁকা থাকত)
        if validated.get('lat') is None and validated.get('lng') is None:
            validated['lat'], validated['lng'] = district_point(district_name)
        farm = Farm.objects.create(**validated)
        self._apply_flora(farm, names)
        return farm

    def update(self, farm, validated):
        names = validated.pop('flora_names', None)
        validated = self._apply_location(validated, farm)
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

    @staticmethod
    def _current_queen(obj):
        # prefetch করা queens থেকে খোঁজা — obj.current_queen (.filter) প্রতিটা
        # বাক্সে আলাদা query চালাত
        return next((q for q in obj.queens.all() if q.removed_on is None), None)

    def get_queen(self, obj):
        return 'আছে' if self._current_queen(obj) else 'নেই'

    def get_queenAge(self, obj):
        queen = self._current_queen(obj)
        if not queen:
            return 0
        days = (timezone.localdate() - queen.installed_on).days
        return max(days // 365, 0)

    def get_last(self, obj):
        latest = obj.inspections.first()
        if not latest:
            return None
        return (timezone.localdate() - latest.inspect_date).days

    def validate_farm(self, farm):
        """শুধু নিজের খামারে বাক্স রাখা যায়।

        আগে যেকোনো খামারের id পাঠিয়ে অন্যের খামারে বাক্স বসানো যেত।
        """
        request = self.context.get('request')
        if request is not None and farm.owner_id != request.user.id:
            raise serializers.ValidationError('এটা আপনার খামার নয়')
        return farm

    def _species(self, validated):
        name = validated.pop('species', None)
        if name:
            validated['species'] = BeeSpecies.objects.get_or_create(name=name.strip())[0]
        return validated

    def create(self, validated):
        if 'species' not in validated or not validated.get('species'):
            raise serializers.ValidationError({'species': 'মৌমাছির প্রজাতি দিন'})
        return Hive.objects.create(**self._species(validated))

    def update(self, hive, validated):
        # খামার বদল শুধু /move/ দিয়ে — যাতে procedure-এর যাচাই আর ইতিহাস বাদ না পড়ে
        if 'farm' in validated and validated['farm'].pk != hive.farm_id:
            raise serializers.ValidationError(
                {'farm': 'বাক্স সরাতে "অন্য খামারে সরান" ব্যবহার করুন'})
        validated.pop('farm', None)
        for key, value in self._species(validated).items():
            setattr(hive, key, value)
        hive.save()
        return hive


class QueenSerializer(serializers.ModelSerializer):
    class Meta:
        model = Queen
        fields = ['id', 'hive', 'source', 'color_mark', 'installed_on', 'removed_on', 'note']
        # বাক্স আসে URL-এর কোড থেকে, তারিখ বসায় sp_new_queen (আজকের দিন) —
        # আগে এ দুটো body-তে না দিলে ৪০০ আসত, অথচ procedure এগুলো ব্যবহারই করত না
        read_only_fields = ['hive', 'installed_on', 'removed_on']


class HiveEventSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.name', read_only=True)
    date = serializers.DateField(source='event_date')

    class Meta:
        model = HiveEvent
        fields = ['id', 'hive', 'date', 'kind', 'note', 'actor', 'actor_name']
        # বাক্সটা URL-এর কোড থেকে আসে (view-এর owned_hive) — body-তে hive
        # চাইলে অন্যের বাক্সের id পাঠানোর রাস্তা খোলা থাকত
        read_only_fields = ['actor', 'hive']


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
        # model-এর (hive, inspect_date) UNIQUE থেকে DRF নিজে একটা ইংরেজি
        # বার্তার validator বানায় — সেটা বাদ দিয়ে নিচে বাংলায় যাচাই
        validators = []

    def validate(self, data):
        if Inspection.objects.filter(hive=data['hive'], inspect_date=data['inspect_date']).exists():
            raise serializers.ValidationError(
                {'date': 'এই বাক্সে এই তারিখে আগেই একটা পরিদর্শন লেখা আছে'})
        return data

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
