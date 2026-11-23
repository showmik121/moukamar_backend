from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse

def home_view(request):
    return JsonResponse({
        "status": "online",
        "message": "মৌখামার (Moukhamar) API ব্যাকএন্ড সার্ভার সক্রিয় আছে।",
        "endpoints": {
            "admin": "/admin/",
            "api_auth": "/api/auth/",
            "api_dashboard": "/api/dashboard/",
            "api_farms": "/api/farms/",
            "api_hives": "/api/hives/",
            "api_inspections": "/api/inspections/",
            "api_harvests": "/api/harvests/",
            "api_notifications": "/api/notifications/",
            "api_community": "/api/community/posts/",
            "api_diseases": "/api/diseases/",
            "api_flora": "/api/flora/"
        }
    }, json_dumps_params={'ensure_ascii': False, 'indent': 2})

urlpatterns = [
    path('', home_view, name='home'),
    path('admin/', admin.site.urls),
    path('api/', include('moukhamar.api_urls')),
]
