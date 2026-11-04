#!/usr/bin/env sh
set -eu

until python - <<'PY'
import os
import sys

import psycopg2

try:
    conn = psycopg2.connect(
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
    )
    conn.close()
    print("Database ready")
    sys.exit(0)
except Exception as exc:
    print(f"Database not ready: {exc}", file=sys.stderr)
    sys.exit(1)
PY

do
    echo "Waiting for database..."
    sleep 2
done

exec "$@"
