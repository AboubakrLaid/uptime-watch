from rest_framework import generics

from main.models import Website
from main.serializers import WebsiteSerializer


class WebsiteListCreateAPIView(generics.ListCreateAPIView):
    queryset = Website.objects.all().order_by("-created_at")
    serializer_class = WebsiteSerializer
