from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Post, Comment
from .serializers import PostSerializer, CommentSerializer


class PostListCreate(generics.ListCreateAPIView):
    serializer_class = PostSerializer

    def get_queryset(self):
        qs = Post.objects.prefetch_related('comments__author').select_related('author')
        cat = self.request.query_params.get('category')
        if cat:
            qs = qs.filter(category=cat)
        return qs

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)


class PostUpvote(APIView):
    def post(self, request, pk):
        try:
            post = Post.objects.get(pk=pk)
        except Post.DoesNotExist:
            return Response({'detail': 'পোস্ট পাওয়া যায়নি'}, status=404)
        post.upvotes += 1
        post.save()
        return Response({'upvotes': post.upvotes})


class CommentCreate(generics.CreateAPIView):
    serializer_class = CommentSerializer

    def perform_create(self, serializer):
        post = Post.objects.get(pk=self.kwargs['pk'])
        serializer.save(author=self.request.user, post=post)
