#!/usr/bin/env bash
set -Eeuo pipefail

BRANCH="${BRANCH:-main}"
ENV="${ENV:-prod}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-373080580380}"
ECR_REPOSITORY="${ECR_REPOSITORY:-uptime-watch}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${REPO_ROOT}/docker-compose-prod.yml}"
APP_SERVICE="${APP_SERVICE:-uptime-watch-app}"
NGINX_SERVICE="${NGINX_SERVICE:-nginx}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${IMAGE_TAG:-}"
APP_HEALTH_TIMEOUT_SECONDS="${APP_HEALTH_TIMEOUT_SECONDS:-180}"
APP_HEALTH_POLL_INTERVAL_SECONDS="${APP_HEALTH_POLL_INTERVAL_SECONDS:-5}"
NGINX_HEALTH_RETRIES="${NGINX_HEALTH_RETRIES:-5}"
NGINX_HEALTH_RETRY_INTERVAL_SECONDS="${NGINX_HEALTH_RETRY_INTERVAL_SECONDS:-2}"
NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS="${NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS:-5}"
PUBLIC_HEALTH_RETRIES="${PUBLIC_HEALTH_RETRIES:-5}"
PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS="${PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS:-5}"
PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS="${PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS:-10}"
export AWS_REGION AWS_ACCOUNT_ID ECR_REPOSITORY ECR_REGISTRY

usage() {
  cat <<EOF
Usage: ./deploy.sh --image-tag IMAGE_TAG [options]

Options:
  -t, --image-tag      Timestamped image tag to deploy (required)
  -b, --branch         Git branch to deploy (default: main)
  -e, --env            Environment name (default: prod)
  -r, --region         AWS region (default: eu-west-3)
  -a, --account-id     AWS account id (default: 373080580380)
  -c, --compose-file   Docker Compose file to use (default: docker-compose-prod.yml)
  -h, --help           Show this help

Verification timing can be configured with APP_HEALTH_TIMEOUT_SECONDS,
APP_HEALTH_POLL_INTERVAL_SECONDS, NGINX_HEALTH_RETRIES,
NGINX_HEALTH_RETRY_INTERVAL_SECONDS, NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS,
PUBLIC_HEALTH_RETRIES, PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS, and
PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS.
EOF
}

validate_positive_integer() {
  local setting_name="$1"
  local setting_value="$2"

  if [[ ! "$setting_value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$setting_name must be a positive integer; got '$setting_value'." >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--image-tag)
      if [[ $# -lt 2 ]]; then
        echo "Option '$1' requires an image tag."
        exit 1
      fi
      IMAGE_TAG="$2"
      shift 2
      ;;
    -b|--branch)
      BRANCH="$2"
      shift 2
      ;;
    -e|--env)
      ENV="$2"
      shift 2
      ;;
    -r|--region)
      AWS_REGION="$2"
      shift 2
      ;;
    -a|--account-id)
      AWS_ACCOUNT_ID="$2"
      shift 2
      ;;
    -c|--compose-file)
      COMPOSE_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

validate_positive_integer APP_HEALTH_TIMEOUT_SECONDS "$APP_HEALTH_TIMEOUT_SECONDS"
validate_positive_integer APP_HEALTH_POLL_INTERVAL_SECONDS "$APP_HEALTH_POLL_INTERVAL_SECONDS"
validate_positive_integer NGINX_HEALTH_RETRIES "$NGINX_HEALTH_RETRIES"
validate_positive_integer NGINX_HEALTH_RETRY_INTERVAL_SECONDS "$NGINX_HEALTH_RETRY_INTERVAL_SECONDS"
validate_positive_integer NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS "$NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS"
validate_positive_integer PUBLIC_HEALTH_RETRIES "$PUBLIC_HEALTH_RETRIES"
validate_positive_integer PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS "$PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS"
validate_positive_integer PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS "$PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS"

if [[ ! "$IMAGE_TAG" =~ ^upwatch-back-[0-9]{8}-[0-9]{6}-[0-9a-f]{7}$ ]]; then
  echo "A valid timestamped image tag is required (upwatch-back-YYYYMMDD-HHMMSS-SHORTSHA)."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to deploy this project."
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required to authenticate with ECR."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for post-deployment HTTPS verification."
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE"
  exit 1
fi

cd "$REPO_ROOT"

echo "Deploying branch '$BRANCH' to environment '$ENV'"

echo "Authenticating Docker to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

if ! aws ecr describe-images \
  --repository-name "$ECR_REPOSITORY" \
  --image-ids "imageTag=${IMAGE_TAG}" \
  --region "$AWS_REGION" > /dev/null; then
  echo "Required image tag '${IMAGE_TAG}' was not found in ECR; deployment cannot continue."
  exit 1
fi

APP_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
export IMAGE_TAG APP_IMAGE

echo "Pulling app image from ECR: $APP_IMAGE"
docker compose -f "$COMPOSE_FILE" pull "$APP_SERVICE"

echo "Starting containers from pulled image..."
docker compose -f "$COMPOSE_FILE" up -d

echo "Running database migrations..."
docker compose -f "$COMPOSE_FILE" exec -T "$APP_SERVICE" python manage.py migrate

echo "Collecting static files..."
docker compose -f "$COMPOSE_FILE" exec -T "$APP_SERVICE" python manage.py collectstatic --clear --no-input

wait_for_app_health() {
  local started_at="$SECONDS"
  local elapsed
  local remaining
  local health_status="unavailable"

  echo "Waiting up to ${APP_HEALTH_TIMEOUT_SECONDS}s for Django readiness..."
  while true; do
    if health_status="$(docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
      "$APP_SERVICE" 2>/dev/null)"; then
      if [[ "$health_status" == "healthy" ]]; then
        echo "Django readiness verification passed."
        return 0
      fi
    else
      health_status="unavailable"
    fi

    elapsed=$((SECONDS - started_at))
    if (( elapsed >= APP_HEALTH_TIMEOUT_SECONDS )); then
      echo "Django readiness verification failed after ${APP_HEALTH_TIMEOUT_SECONDS}s (last Docker health status: ${health_status})." >&2
      docker compose -f "$COMPOSE_FILE" ps -a "$APP_SERVICE" >&2 || true
      docker compose -f "$COMPOSE_FILE" logs --tail=50 "$APP_SERVICE" >&2 || true
      return 1
    fi

    remaining=$((APP_HEALTH_TIMEOUT_SECONDS - elapsed))
    if (( remaining < APP_HEALTH_POLL_INTERVAL_SECONDS )); then
      sleep "$remaining"
    else
      sleep "$APP_HEALTH_POLL_INTERVAL_SECONDS"
    fi
  done
}

verify_nginx_health() {
  local attempt
  local http_status="000"

  echo "Verifying Nginx's local HTTPS /nginx-health endpoint, independently of public readiness..."
  for ((attempt = 1; attempt <= NGINX_HEALTH_RETRIES; attempt++)); do
    if http_status="$(docker compose -f "$COMPOSE_FILE" exec -T "$NGINX_SERVICE" \
      curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
      --connect-timeout "$NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS" \
      --max-time "$NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS" \
      --noproxy '*' \
      --resolve upwatch.live:443:127.0.0.1 \
      https://upwatch.live/nginx-health)"; then
      if [[ "$http_status" == "200" ]]; then
        echo "Nginx health verification passed."
        return 0
      fi
    fi

    if (( attempt < NGINX_HEALTH_RETRIES )); then
      sleep "$NGINX_HEALTH_RETRY_INTERVAL_SECONDS"
    fi
  done

  echo "Nginx health verification failed after ${NGINX_HEALTH_RETRIES} attempts (last HTTP status: ${http_status:-000})." >&2
  docker compose -f "$COMPOSE_FILE" ps -a "$NGINX_SERVICE" >&2 || true
  docker compose -f "$COMPOSE_FILE" logs --tail=50 "$NGINX_SERVICE" >&2 || true
  return 1
}

verify_public_health() {
  local attempt
  local http_status="000"
  local curl_output=""
  local curl_error=""
  local curl_exit_status
  local last_result="no response"

  echo "Verifying public HTTPS readiness at https://upwatch.live/health/ready/..."
  for ((attempt = 1; attempt <= PUBLIC_HEALTH_RETRIES; attempt++)); do
    if curl_output="$(curl --silent --show-error --output /dev/null --write-out $'\n%{http_code}' \
      --connect-timeout "$PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS" \
      --max-time "$PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS" \
      https://upwatch.live/health/ready/ 2>&1)"; then
      curl_exit_status=0
    else
      curl_exit_status=$?
    fi

    http_status="${curl_output##*$'\n'}"
    if [[ "$curl_output" == *$'\n'* ]]; then
      curl_error="${curl_output%$'\n'*}"
    else
      curl_error="$curl_output"
    fi

    if (( curl_exit_status == 0 )); then
      last_result="HTTP status ${http_status}"
      if [[ "$http_status" == "200" ]]; then
        echo "Public HTTPS verification passed."
        return 0
      fi
    else
      last_result="curl error: ${curl_error:-exit status ${curl_exit_status}}"
    fi

    if (( attempt < PUBLIC_HEALTH_RETRIES )); then
      sleep "$PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS"
    fi
  done

  echo "Public HTTPS verification failed after ${PUBLIC_HEALTH_RETRIES} attempts (final result: ${last_result})." >&2
  echo "Container status:" >&2
  docker compose -f "$COMPOSE_FILE" ps -a "$APP_SERVICE" "$NGINX_SERVICE" >&2 || true
  echo "Recent application and Nginx logs:" >&2
  docker compose -f "$COMPOSE_FILE" logs --tail=50 "$APP_SERVICE" "$NGINX_SERVICE" >&2 || true
  return 1
}

wait_for_app_health
verify_nginx_health
verify_public_health

echo "Deployment for '$BRANCH' completed successfully."
