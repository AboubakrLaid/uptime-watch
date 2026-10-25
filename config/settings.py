import os
import sys
from pathlib import Path

import dotenv
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def get_env_value(name: str, *, required: bool = False):
    value = os.getenv(name)
    if required and (value is None or value == ""):
        raise ImproperlyConfigured(f"Missing required environment variable: {name}")
    return value


if not os.getenv("ENV"):
    env_file = BASE_DIR / "envs" / ".env.dev"
    root_env = BASE_DIR / ".env"
    env_path = (
        env_file if env_file.exists() else root_env if root_env.exists() else None
    )

    if env_path is not None:
        dotenv.load_dotenv(env_path)

        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                if not line.strip() or line.startswith("#"):
                    continue
                key, value = line.strip().split("=", 1)
                if key in ["DB_HOST", "REDIS_HOST"]:
                    value = "localhost"
                if key == "ELASTIC_HOST":
                    value = "http://localhost:9200"
                if not os.getenv(key):
                    os.environ[key] = value


ENV = get_env_value("ENV", required=True)
DEBUG = get_env_value("DEBUG", required=True).lower() in {"1", "true", "yes", "on"}
SECRET_KEY = get_env_value("DJANGO_SECRET_KEY", required=True)
BACK_HOST = get_env_value("BACK_HOST", required=True)
DJANGO_PORT = get_env_value("DJANGO_PORT", required=True)
POSTGRES_DB = get_env_value("POSTGRES_DB", required=True)
POSTGRES_USER = get_env_value("POSTGRES_USER", required=True)
POSTGRES_PASSWORD = get_env_value("POSTGRES_PASSWORD", required=True)
DB_HOST = get_env_value("DB_HOST", required=True)
DB_PORT = get_env_value("DB_PORT", required=True)

ALLOWED_HOSTS = ["127.0.0.1", "localhost", "0.0.0.0"]

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
