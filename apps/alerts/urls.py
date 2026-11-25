from django.urls import path

from .views import MarkAllRead, NotificationList, SprayAlertListCreate

urlpatterns = [
    path('notifications/', NotificationList.as_view()),
    path('notifications/read-all/', MarkAllRead.as_view()),
    path('spray-alerts/', SprayAlertListCreate.as_view()),
]
