from rest_framework import serializers

from .models import Comment, Post, Tag


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.name', read_only=True)

    class Meta:
        model = Comment
        fields = ['id', 'post', 'text', 'author', 'author_name', 'created_at']
        read_only_fields = ['post', 'author', 'created_at']


class PostSerializer(serializers.ModelSerializer):
    """কমিউনিটির পোস্ট।

    ট্যাগ আগে একটা কলামে কমা দিয়ে লেখা হতো; এখন post_tags junction।
    frontend যেহেতু `tags` নামে একটা তালিকাই চায়, সেই আকারই পাঠানো হয়।
    """

    author_name = serializers.CharField(source='author.name', read_only=True)
    author_upazila = serializers.CharField(source='author.upazila.name', read_only=True,
                                           default='')
    author_district = serializers.CharField(source='author.upazila.district.name',
                                            read_only=True, default='')
    author_phone = serializers.CharField(source='author.phone', read_only=True, default='')
    author_farm = serializers.SerializerMethodField()
    upvoted = serializers.SerializerMethodField()
    comments = CommentSerializer(many=True, read_only=True)
    tags = serializers.SerializerMethodField()
    tag_names = serializers.ListField(child=serializers.CharField(), write_only=True,
                                      required=False)
    upvotes = serializers.IntegerField(source='upvote_count', read_only=True)

    class Meta:
        model = Post
        fields = ['id', 'category', 'title', 'body', 'resource_type', 'price',
                  'upvotes', 'upvoted', 'tags', 'tag_names', 'author', 'author_name',
                  'author_upazila', 'author_district', 'author_phone', 'author_farm',
                  'comments', 'created_at']
        read_only_fields = ['author', 'created_at']

    def get_tags(self, obj):
        return [t.name for t in obj.tags.all()]

    def get_author_farm(self, obj):
        profile = getattr(obj.author, 'farmer_profile', None)
        return profile.farm_name if profile else ''

    def get_upvoted(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        return any(v.user_id == request.user.id for v in obj.votes.all())

    def create(self, validated):
        names = validated.pop('tag_names', [])
        post = Post.objects.create(**validated)
        if names:
            post.tags.set([Tag.objects.get_or_create(name=n.strip())[0]
                           for n in names if n and n.strip()])
        return post
