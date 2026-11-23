from django.urls import path
from .views import (FarmListCreate, FarmDetail, HiveListCreate, HiveDetail,
                    InspectionListCreate, HarvestListCreate, DashboardView)

urlpatterns = [
    path('dashboard/', DashboardView.as_view()),
    path('farms/', FarmListCreate.as_view()),
    path('farms/<int:pk>/', FarmDetail.as_view()),
    path('hives/', HiveListCreate.as_view()),
    path('hives/<str:code>/', HiveDetail.as_view()),
    path('inspections/', InspectionListCreate.as_view()),
    path('harvests/', HarvestListCreate.as_view()),
]
