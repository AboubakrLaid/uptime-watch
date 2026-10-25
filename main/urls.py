from django.urls import path

from .views import WebsiteListCreateAPIView

urlpatterns = [
    path(
        "api/websites/", WebsiteListCreateAPIView.as_view(), name="website-list-create"
    ),
]
