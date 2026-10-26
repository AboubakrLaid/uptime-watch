import importlib
import os
import sys
import unittest


class SettingsEnvironmentTests(unittest.TestCase):
    def reload_settings(self, env_value, extra_env=None):
        for key in [
            "ENV",
            "DEBUG",
            "DJANGO_SECRET_KEY",
            "BACK_HOST",
            "DJANGO_PORT",
            "POSTGRES_DB",
            "POSTGRES_USER",
            "POSTGRES_PASSWORD",
            "DB_HOST",
            "DB_PORT",
        ]:
            os.environ.pop(key, None)

        if env_value is not None:
            os.environ["ENV"] = env_value

        if extra_env:
            for key, value in extra_env.items():
                os.environ[key] = value

        sys.modules.pop("config.settings", None)
        return importlib.import_module("config.settings")

    def test_development_uses_local_defaults(self):
        settings = self.reload_settings("DEV")

        self.assertEqual(settings.ENV, "DEV")
        self.assertTrue(settings.DEBUG)
        self.assertEqual(settings.DB_HOST, "127.0.0.1")
        self.assertEqual(settings.DJANGO_PORT, "8000")

    def test_testing_uses_pipeline_environment(self):
        settings = self.reload_settings("TESTING")

        self.assertEqual(settings.ENV, "TESTING")
        self.assertFalse(settings.DEBUG)
        self.assertEqual(settings.POSTGRES_DB, "uptime_watch_ci")
        self.assertEqual(settings.DB_HOST, "127.0.0.1")

    def test_production_requires_runtime_secrets(self):
        with self.assertRaises(Exception):
            self.reload_settings("PROD")
