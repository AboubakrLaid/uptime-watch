from rest_framework import serializers

from main.models import Website


class WebsiteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Website
        fields = ["id", "name", "url", "created_at"]
        read_only_fields = ["id", "created_at"]
