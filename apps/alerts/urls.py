from django.urls import path

from .views import MarkAllRead, NotificationList, NotificationRead, SprayAlertListCreate

urlpatterns = [
    path('notifications/', NotificationList.as_view()),
    path('notifications/read-all/', MarkAllRead.as_view()),
    path('notifications/<int:pk>/read/', NotificationRead.as_view()),
    path('spray-alerts/', SprayAlertListCreate.as_view()),
]
