from django.contrib import admin
from .models import Post, Tag, PostVote, Comment


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ['name']
    search_fields = ['name']


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'category', 'upvote_count', 'created_at']
    list_filter = ['category']
    search_fields = ['title', 'body']
    filter_horizontal = ['tags']
    readonly_fields = ['upvote_count']


@admin.register(PostVote)
class PostVoteAdmin(admin.ModelAdmin):
    list_display = ['post', 'user', 'created_at']


@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display = ['post', 'author', 'created_at']
