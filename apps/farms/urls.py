from django.urls import path

from .views import (DashboardView, FarmDetail, FarmHiveSummary, FarmListCreate,
                    HarvestListCreate, HiveDetail, HiveEventList, HiveListCreate,
                    HiveStatusView, InspectionListCreate, MonthlyHoneyView,
                    MoveHiveView, QueenListCreate, RemindOverdueView,
                    SeasonReportView)

urlpatterns = [
    path('dashboard/', DashboardView.as_view()),
    path('farms/', FarmListCreate.as_view()),
    path('farms/summary/', FarmHiveSummary.as_view()),
    path('farms/<int:pk>/', FarmDetail.as_view()),
    path('hives/', HiveListCreate.as_view()),
    # status/ আর remind-overdue/ কে <str:code>-এর আগে রাখতে হবে, নাহলে
    # এগুলো বাক্সের কোড হিসেবে ধরা পড়বে
    path('hives/status/', HiveStatusView.as_view()),
    path('hives/remind-overdue/', RemindOverdueView.as_view()),
    path('hives/<str:code>/', HiveDetail.as_view()),
    path('hives/<str:code>/events/', HiveEventList.as_view()),
    path('hives/<str:code>/queens/', QueenListCreate.as_view()),
    path('hives/<str:code>/move/', MoveHiveView.as_view()),
    path('inspections/', InspectionListCreate.as_view()),
    path('harvests/', HarvestListCreate.as_view()),
    path('reports/monthly-honey/', MonthlyHoneyView.as_view()),
    path('reports/season/', SeasonReportView.as_view()),
]
