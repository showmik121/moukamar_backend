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
    author_upazila = serializers.CharField(source='author.upazila.name', read_only=True)
    comments = CommentSerializer(many=True, read_only=True)
    tags = serializers.SerializerMethodField()
    tag_names = serializers.ListField(child=serializers.CharField(), write_only=True,
                                      required=False)
    upvotes = serializers.IntegerField(source='upvote_count', read_only=True)

    class Meta:
        model = Post
        fields = ['id', 'category', 'title', 'body', 'resource_type', 'price',
                  'upvotes', 'tags', 'tag_names', 'author', 'author_name',
                  'author_upazila', 'comments', 'created_at']
        read_only_fields = ['author', 'created_at']

    def get_tags(self, obj):
        return [t.name for t in obj.tags.all()]

    def create(self, validated):
        names = validated.pop('tag_names', [])
        post = Post.objects.create(**validated)
        if names:
            post.tags.set([Tag.objects.get_or_create(name=n.strip())[0]
                           for n in names if n and n.strip()])
        return post
