from django.urls import path

from .views.user import UserListCreateAPIView
from .views.website import WebsiteListCreateAPIView

urlpatterns = [
    path("api/users/", UserListCreateAPIView.as_view(), name="user-list-create"),
    path(
        "api/websites/", WebsiteListCreateAPIView.as_view(), name="website-list-create"
    ),
]
