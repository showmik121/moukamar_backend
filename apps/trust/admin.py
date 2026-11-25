from django.contrib import admin
from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ['table_name', 'row_pk', 'action', 'actor', 'changed_at']
    list_filter = ['table_name', 'action']
    readonly_fields = ['table_name', 'row_pk', 'action', 'actor', 'old_data', 'new_data', 'changed_at']

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
