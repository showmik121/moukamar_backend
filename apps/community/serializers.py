from rest_framework import serializers
from .models import Post, Comment
from apps.accounts.serializers import UserSerializer


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.name', read_only=True)

    class Meta:
        model = Comment
        fields = ['id', 'author', 'author_name', 'text', 'created_at']
        read_only_fields = ['author', 'created_at']


class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.name', read_only=True)
    author_district = serializers.CharField(source='author.district', read_only=True)
    author_farm = serializers.CharField(source='author.farm_name', read_only=True)
    comments = CommentSerializer(many=True, read_only=True)
    comment_count = serializers.IntegerField(source='comments.count', read_only=True)

    class Meta:
        model = Post
        fields = '__all__'
        read_only_fields = ['author', 'upvotes', 'created_at']
