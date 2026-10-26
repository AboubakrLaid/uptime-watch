import os
import sys
from pathlib import Path

import dotenv
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def get_env_value(name: str, *, required: bool = False, default=None):
    value = os.getenv(name)
    if value is None or value == "":
        if default is not None:
            return default
        if required:
            raise ImproperlyConfigured(f"Missing required environment variable: {name}")
        return None
    return value


ENV = os.getenv("ENV")
if ENV is None:
    dotenv.load_dotenv(BASE_DIR / ".env")
    ENV = os.getenv("ENV", "DEV")

ENV = ENV.upper()
if ENV not in {"DEV", "PROD"}:
    raise ImproperlyConfigured("ENV must be one of: DEV, PROD")

DEBUG = get_env_value("DEBUG", default="True" if ENV == "DEV" else "False").lower() in {
    "1",
    "true",
    "yes",
    "on",
}

if ENV == "PROD":
    SECRET_KEY = get_env_value("DJANGO_SECRET_KEY", required=True)
    BACK_HOST = get_env_value("BACK_HOST", required=True)
    POSTGRES_DB = get_env_value("POSTGRES_DB", required=True)
    POSTGRES_USER = get_env_value("POSTGRES_USER", required=True)
    POSTGRES_PASSWORD = get_env_value("POSTGRES_PASSWORD", required=True)
    DB_HOST = get_env_value("DB_HOST", required=True)
else:
    SECRET_KEY = get_env_value("DJANGO_SECRET_KEY", default="dev-secret-key-change-me")
    BACK_HOST = get_env_value("BACK_HOST", default="http://127.0.0.1:8000")
    POSTGRES_DB = get_env_value(
        "POSTGRES_DB", default="uptime_watch_dev" if ENV == "DEV" else "uptime_watch_ci"
    )
    POSTGRES_USER = get_env_value("POSTGRES_USER", default="uptime_watch_dev")
    POSTGRES_PASSWORD = get_env_value(
        "POSTGRES_PASSWORD", default="dev-password-change-me"
    )
    DB_HOST = get_env_value("DB_HOST", default="127.0.0.1")

DJANGO_PORT = get_env_value("DJANGO_PORT", default="8000")
DB_PORT = get_env_value("DB_PORT", default="5432")
ALLOWED_HOSTS = get_env_value(
    "ALLOWED_HOSTS", default="127.0.0.1,localhost,0.0.0.0"
).split(",")
ALLOWED_HOSTS = [host.strip() for host in ALLOWED_HOSTS if host.strip()]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "django_extensions",
    "main",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

if "test" in sys.argv:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "test_db.sqlite3",
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": POSTGRES_DB,
            "USER": POSTGRES_USER,
            "PASSWORD": POSTGRES_PASSWORD,
            "HOST": DB_HOST,
            "PORT": DB_PORT,
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"
    },
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "main.User"

REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.AllowAny",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
}
