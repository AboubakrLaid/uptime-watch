# Uptime Watch

A minimal Django REST Framework project for tracking website uptime data in a later DevOps learning path.

## Project structure

```text
uptime-watch/
├── config/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   ├── asgi.py
│   └── wsgi.py
├── main/
│   ├── migrations/
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── website.py
│   ├── serializers/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── website.py
│   ├── fixtures/
│   ├── management/
│   ├── admin/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── website.py
│   ├── __init__.py
│   ├── apps.py
│   ├── urls.py
│   └── views.py
├── tests/
│   ├── __init__.py
│   ├── test_users.py
│   └── test_websites.py
├── envs/
│   ├── .env.dev
│   └── .env.example
├── .gitignore
├── manage.py
├── requirements.txt
└── README.md
```

## Local setup

### 1. Create and activate a virtual environment

```bash
cd uptime-watch
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Install dependencies

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### 3. Configure PostgreSQL locally

Create a PostgreSQL database and user matching the values in `envs/.env.dev`:

```sql
CREATE DATABASE uptime_watch_dev;
CREATE USER uptime_watch_dev WITH PASSWORD 'replace_with_a_new_local_database_password';
ALTER ROLE uptime_watch_dev WITH SUPERUSER;
ALTER DATABASE uptime_watch_dev OWNER TO uptime_watch_dev;
```

Update the password in `envs/.env.dev` to the actual password you created locally.

### 4. Load the development environment

The project loads the environment variables from `envs/.env.dev` relative to the project root.

```bash
set -a
source envs/.env.dev
set +a
```

This file is intentionally ignored by Git.

### 5. Generate and apply migrations

```bash
python manage.py makemigrations main
python manage.py migrate
```

If PostgreSQL is not running locally, start it before running the migration commands.

### 6. Create a superuser

```bash
python manage.py createsuperuser
```

### 7. Start the development server

```bash
python manage.py runserver
```

The API will be available at:

- `http://127.0.0.1:8000/api/websites/`
- `http://127.0.0.1:8000/admin/`

## API usage

### List websites

```bash
curl http://127.0.0.1:8000/api/websites/
```

### Register a website

```bash
curl -X POST http://127.0.0.1:8000/api/websites/ \
  -H "Content-Type: application/json" \
  -d '{"name":"Example","url":"https://example.com"}'
```

## Running tests

```bash
python manage.py test tests
```

This project configures Django test discovery so the tests under `tests/` are discovered correctly.

## Notes

- The project uses a custom user model with `email` as the username field.
- Secrets are loaded from environment variables and not hardcoded in the codebase.
- The debug flag and database configuration are controlled by the environment file.
- The project is intentionally minimal and ready for progressively adding DevOps and monitoring learning milestones.
