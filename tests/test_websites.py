from django.test import TestCase
from rest_framework.test import APIClient

from main.models import Website
from main.views.website import WebsiteListCreateAPIView


class WebsiteAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.assertTrue(issubclass(WebsiteListCreateAPIView, object))

    def test_list_websites(self):
        Website.objects.create(name="Example", url="https://example.com")

        response = self.client.get("/api/websites/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data[0]["name"], "Example")
        self.assertEqual(response.data[0]["url"], "https://example.com")

    def test_create_website(self):
        payload = {
            "name": "Uptime Watch",
            "url": "https://uptimewatch.example",
        }

        response = self.client.post("/api/websites/", payload, format="json")

        self.assertEqual(response.status_code, 201)
        self.assertEqual(Website.objects.count(), 1)
        self.assertEqual(Website.objects.get().name, "Uptime Watch")

    def test_invalid_website_data(self):
        payload = {
            "name": "",
            "url": "not-a-valid-url",
        }

        response = self.client.post("/api/websites/", payload, format="json")

        self.assertEqual(response.status_code, 400)
        self.assertIn("name", response.data)
        self.assertIn("url", response.data)
