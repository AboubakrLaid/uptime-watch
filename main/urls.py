from django.urls import path

from .views.health import DeepHealthView, HealthView, ReadyHealthView
from .views.user import UserListCreateAPIView
from .views.website import WebsiteListCreateAPIView

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("health/ready/", ReadyHealthView.as_view(), name="health-ready"),
    path("health/deep/", DeepHealthView.as_view(), name="health-deep"),
    path("api/users/", UserListCreateAPIView.as_view(), name="user-list-create"),
    path(
        "api/websites/", WebsiteListCreateAPIView.as_view(), name="website-list-create"
    ),
]
