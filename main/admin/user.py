from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from main.models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ["email", "name", "is_staff", "is_superuser", "created_at"]
    search_fields = ["email", "name"]
    ordering = ["email"]
    readonly_fields = ["created_at"]

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Personal info", {"fields": ("name",)}),
        (
            "Permissions",
            {
                "fields": (
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "groups",
                    "user_permissions",
                )
            },
        ),
        ("Important dates", {"fields": ("last_login", "created_at")}),
    )

    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("name", "email", "password1", "password2"),
            },
        ),
    )
