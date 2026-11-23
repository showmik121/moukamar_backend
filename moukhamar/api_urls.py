from django.urls import path, include

urlpatterns = [
    path('auth/', include('apps.accounts.urls')),
    path('', include('apps.farms.urls')),
    path('', include('apps.alerts.urls')),
    path('', include('apps.community.urls')),
    path('', include('apps.reference.urls')),
]
