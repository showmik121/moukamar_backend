from django.db import transaction
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Post, PostVote
from .serializers import CommentSerializer, PostSerializer


class PostListCreate(generics.ListCreateAPIView):
    serializer_class = PostSerializer

    def get_queryset(self):
        qs = (Post.objects
              .select_related('author__upazila')
              .prefetch_related('tags', 'comments__author'))
        category = self.request.query_params.get('category')
        tag = self.request.query_params.get('tag')
        if category:
            qs = qs.filter(category=category)
        if tag:
            qs = qs.filter(tags__name=tag)
        return qs

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)


class PostUpvote(APIView):
    """upvote দেওয়া।

    দুটো নিয়ম ডাটাবেজে বসানো, Python-এ নয়:
      • একজন একবারই দিতে পারে — post_votes-এর UNIQUE constraint
      • posts.upvote_count গণনা — trg_post_vote_after_insert trigger
    তাই এখানে শুধু একটা ভোটের সারি বসানো হয়; গণনা আপনা থেকে ঠিক থাকে।
    """

    @transaction.atomic
    def post(self, request, pk):
        post = Post.objects.filter(pk=pk).first()
        if not post:
            return Response({'detail': 'পোস্ট পাওয়া যায়নি'}, status=404)

        _, created = PostVote.objects.get_or_create(post=post, user=request.user)
        if not created:
            return Response({'detail': 'আপনি আগেই upvote দিয়েছেন',
                             'upvotes': post.upvote_count}, status=409)

        post.refresh_from_db(fields=['upvote_count'])
        return Response({'upvotes': post.upvote_count})


class CommentCreate(generics.CreateAPIView):
    serializer_class = CommentSerializer

    def perform_create(self, serializer):
        post = Post.objects.get(pk=self.kwargs['pk'])
        serializer.save(author=self.request.user, post=post)
