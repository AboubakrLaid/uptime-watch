from django.db import connection
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView


class ReadyHealthView(APIView):
    permission_classes = []

    def get(self, request, *args, **kwargs):
        checks = {
            "database": {
                "healthy": False,
                "status": "error",
                "details": "Database connectivity check has not run yet.",
            }
        }

        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
            checks["database"] = {
                "healthy": True,
                "status": "ok",
                "details": "Database connectivity check passed.",
            }
            payload = {"healthy": True, "checks": checks}
            return Response(payload, status=status.HTTP_200_OK)
        except (
            Exception
        ) as exc:  # pragma: no cover - this path is exercised by the live app
            checks["database"] = {
                "healthy": False,
                "status": "error",
                "details": str(exc),
            }
            payload = {"healthy": False, "checks": checks}
            return Response(payload, status=status.HTTP_503_SERVICE_UNAVAILABLE)


class DeepHealthView(APIView):
    permission_classes = []

    def get(self, request, *args, **kwargs):
        # Optional dependency checks are intentionally kept as a pass for now.
        # Once Redis, Celery, Elasticsearch, or other services are added, expand this
        # endpoint to validate those dependencies before routing traffic to the app.
        checks = {
            "optional_services": {
                "healthy": True,
                "status": "pending",
                "details": "No optional services are configured yet; deep checks are intentionally passing for now.",
            }
        }
        payload = {"healthy": True, "checks": checks}
        return Response(payload, status=status.HTTP_200_OK)


class HealthView(APIView):
    permission_classes = []

    def get(self, request, *args, **kwargs):
        ready_response = ReadyHealthView.as_view()(request, *args, **kwargs)
        deep_response = DeepHealthView.as_view()(request, *args, **kwargs)

        payload = {
            "healthy": ready_response.data["healthy"] and deep_response.data["healthy"],
            "checks": {
                "ready": ready_response.data["checks"],
                "deep": deep_response.data["checks"],
            },
        }

        status_code = (
            status.HTTP_200_OK
            if payload["healthy"]
            else status.HTTP_503_SERVICE_UNAVAILABLE
        )
        return Response(payload, status=status_code)
