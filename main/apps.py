from django.apps import AppConfig
from django.db import connection


class MainConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "main"

    def ready(self):
        self.startup_validated = False

        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
            self.startup_validated = True
            print("Startup validation passed: database is available.")
        except Exception as exc:
            raise RuntimeError(
                f"Startup validation failed: database is unavailable. {exc}"
            ) from exc
