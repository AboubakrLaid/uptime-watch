from rest_framework import generics

from main.models import User
from main.serializers import UserSerializer


class UserListCreateAPIView(generics.ListCreateAPIView):
    queryset = User.objects.all().order_by("-created_at")
    serializer_class = UserSerializer
