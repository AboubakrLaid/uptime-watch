import main
from unittest.mock import patch

from django.test import TestCase
from rest_framework.test import APIClient

from main.apps import MainConfig


class HealthEndpointTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_ready_health_endpoint_reports_database_status(self):
        response = self.client.get("/health/ready/")

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["healthy"])
        self.assertTrue(response.data["checks"]["database"]["healthy"])

    def test_deep_health_endpoint_is_pass_for_now(self):
        response = self.client.get("/health/deep/")

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["healthy"])
        self.assertIn("pending", response.data["checks"]["optional_services"]["status"])

    def test_ready_health_endpoint_reports_database_error(self):
        with patch("main.views.health.connection.cursor") as mock_cursor:
            mock_cursor.side_effect = Exception("database unavailable")

            response = self.client.get("/health/ready/")

        self.assertEqual(response.status_code, 503)
        self.assertFalse(response.data["healthy"])
        self.assertFalse(response.data["checks"]["database"]["healthy"])

    def test_app_ready_validation_runs(self):
        app_config = MainConfig("main", main)
        app_config.ready()

        self.assertTrue(getattr(app_config, "startup_validated", False))

    def test_app_ready_validation_fails_when_database_is_unavailable(self):
        with patch("main.apps.connection.cursor") as mock_cursor:
            mock_cursor.side_effect = Exception("database unavailable")

            app_config = MainConfig("main", main)

            with self.assertRaisesRegex(RuntimeError, "Startup validation failed"):
                app_config.ready()
