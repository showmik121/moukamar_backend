from django.urls import path
from .views import PostListCreate, PostUpvote, CommentCreate

urlpatterns = [
    path('community/posts/', PostListCreate.as_view()),
    path('community/posts/<int:pk>/upvote/', PostUpvote.as_view()),
    path('community/posts/<int:pk>/comments/', CommentCreate.as_view()),
]
