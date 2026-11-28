from django.conf import settings
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path, re_path
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.static import serve


def api_status(request):
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


@ensure_csrf_cookie
def frontend_page(request, path='index.html'):
    """frontend-এর একটা .html পাতা পাঠায়।

    ensure_csrf_cookie — পাতা খোলার সাথেই csrftoken cookie বসে, তাই
    frontend-এর প্রথম POST থেকেই X-CSRFToken header পাঠানো যায়।
    """
    return serve(request, path, document_root=settings.FRONTEND_DIR)


def frontend_asset(request, path):
    return serve(request, path, document_root=settings.FRONTEND_DIR)


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api_status, name='api-status'),
    path('api/', include('moukhamar.api_urls')),
    # ---- frontend (একই origin) ----
    path('', frontend_page, name='home'),
    re_path(r'^(?P<path>[\w\-]+\.html)$', frontend_page),
    re_path(r'^(?P<path>(?:css|js|build|img)/.+)$', frontend_asset),
]
