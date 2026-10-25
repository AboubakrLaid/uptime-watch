from django.db import models

from main.managers.website import WebsiteManager


class Website(models.Model):
    name = models.CharField(max_length=255)
    url = models.URLField()
    created_at = models.DateTimeField(auto_now_add=True)

    objects = WebsiteManager()

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.name
