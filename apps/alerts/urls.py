from django.urls import path
from .views import NotificationList, MarkAllRead, SprayAlertCreate

urlpatterns = [
    path('notifications/', NotificationList.as_view()),
    path('notifications/read-all/', MarkAllRead.as_view()),
    path('spray-alerts/', SprayAlertCreate.as_view()),
]
