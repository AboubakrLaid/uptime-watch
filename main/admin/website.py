from django.contrib import admin

from main.models import Website


@admin.register(Website)
class WebsiteAdmin(admin.ModelAdmin):
    list_display = ["name", "url", "created_at"]
    search_fields = ["name", "url"]
    ordering = ["-created_at"]
