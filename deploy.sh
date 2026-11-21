#!/usr/bin/env bash
set -Eeuo pipefail

BRANCH="${BRANCH:-main}"
ENV="${ENV:-prod}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-373080580380}"
ECR_REPOSITORY="${ECR_REPOSITORY:-uptime-watch}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${REPO_ROOT}/docker-compose-prod.yml}"
STATIC_DIR="${STATIC_DIR:-${REPO_ROOT}/staticfiles}"
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

DEPLOYMENT_OUTCOME="deployment_failed"
ROLLBACK_ATTEMPTED="no"
ROLLBACK_OUTCOME="not_attempted"
ATTEMPTED_IMAGE=""
PREVIOUS_IMAGE_ID=""
PREVIOUS_IMAGE_REFERENCE=""
RESTORED_IMAGE_REFERENCE=""
APP_RESTORE_OUTCOME="not_attempted"
STATIC_RESTORE_OUTCOME="not_needed"
FAILURE_STAGE=""
FAILURE_STATUS=0
STATIC_MUTATION_STARTED="no"

emit_deployment_summary() {
  printf 'DEPLOYMENT_OUTCOME=%s\n' "$DEPLOYMENT_OUTCOME"
  printf 'ROLLBACK_ATTEMPTED=%s\n' "$ROLLBACK_ATTEMPTED"
  printf 'ROLLBACK_OUTCOME=%s\n' "$ROLLBACK_OUTCOME"
  printf 'ATTEMPTED_IMAGE=%s\n' "$ATTEMPTED_IMAGE"
  printf 'PREVIOUS_IMAGE_ID=%s\n' "$PREVIOUS_IMAGE_ID"
  printf 'PREVIOUS_IMAGE_REFERENCE=%s\n' "$PREVIOUS_IMAGE_REFERENCE"
  printf 'RESTORED_IMAGE_REFERENCE=%s\n' "$RESTORED_IMAGE_REFERENCE"
  printf 'APP_RESTORE_OUTCOME=%s\n' "$APP_RESTORE_OUTCOME"
  printf 'STATIC_RESTORE_OUTCOME=%s\n' "$STATIC_RESTORE_OUTCOME"
  printf 'FAILURE_STAGE=%s\n' "$FAILURE_STAGE"
  printf 'FAILURE_STATUS=%s\n' "$FAILURE_STATUS"
}

preflight_failure() {
  local failure_status="$1"
  local failure_stage="$2"

  DEPLOYMENT_OUTCOME="deployment_failed"
  ROLLBACK_ATTEMPTED="no"
  ROLLBACK_OUTCOME="not_attempted"
  FAILURE_STAGE="$failure_stage"
  FAILURE_STATUS="$failure_status"
  echo "Deployment preflight failed during '$FAILURE_STAGE' (exit status $FAILURE_STATUS)." >&2
  emit_deployment_summary
  exit "$FAILURE_STATUS"
}

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
    return 1
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

validate_positive_integer APP_HEALTH_TIMEOUT_SECONDS "$APP_HEALTH_TIMEOUT_SECONDS" || preflight_failure 2 "validate APP_HEALTH_TIMEOUT_SECONDS"
validate_positive_integer APP_HEALTH_POLL_INTERVAL_SECONDS "$APP_HEALTH_POLL_INTERVAL_SECONDS" || preflight_failure 2 "validate APP_HEALTH_POLL_INTERVAL_SECONDS"
validate_positive_integer NGINX_HEALTH_RETRIES "$NGINX_HEALTH_RETRIES" || preflight_failure 2 "validate NGINX_HEALTH_RETRIES"
validate_positive_integer NGINX_HEALTH_RETRY_INTERVAL_SECONDS "$NGINX_HEALTH_RETRY_INTERVAL_SECONDS" || preflight_failure 2 "validate NGINX_HEALTH_RETRY_INTERVAL_SECONDS"
validate_positive_integer NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS "$NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS" || preflight_failure 2 "validate NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS"
validate_positive_integer PUBLIC_HEALTH_RETRIES "$PUBLIC_HEALTH_RETRIES" || preflight_failure 2 "validate PUBLIC_HEALTH_RETRIES"
validate_positive_integer PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS "$PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS" || preflight_failure 2 "validate PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS"
validate_positive_integer PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS "$PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS" || preflight_failure 2 "validate PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS"

if [[ ! "$IMAGE_TAG" =~ ^upwatch-back-[0-9]{8}-[0-9]{6}-[0-9a-f]{7}$ ]]; then
  echo "A valid timestamped image tag is required (upwatch-back-YYYYMMDD-HHMMSS-SHORTSHA)."
  preflight_failure 2 "validate image tag"
fi
ATTEMPTED_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to deploy this project."
  preflight_failure 1 "check Docker dependency"
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required to authenticate with ECR."
  preflight_failure 1 "check AWS CLI dependency"
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for post-deployment HTTPS verification."
  preflight_failure 1 "check curl dependency"
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE"
  preflight_failure 1 "check Compose file"
fi

if [[ "${UPWATCH_DEPLOY_LOCK_HELD:-0}" != "1" ]]; then
  if ! command -v flock >/dev/null 2>&1; then
    echo "flock is required to prevent concurrent deployments."
    preflight_failure 1 "check flock dependency"
  fi
  if [[ -z "${HOME:-}" ]]; then
    echo "HOME must be set to locate the deployment lock."
    preflight_failure 1 "locate deployment lock"
  fi

  DEPLOY_LOCK_FILE="${DEPLOY_LOCK_FILE:-${HOME}/.uptime-watch-deploy.lock}"
  if ! exec {DEPLOY_LOCK_FD}>"$DEPLOY_LOCK_FILE"; then
    preflight_failure 1 "open deployment lock"
  fi
  if ! flock -n -E 75 "$DEPLOY_LOCK_FD"; then
    echo "Another deployment is already in progress; refusing to change production." >&2
    preflight_failure 75 "deployment lock"
  fi
fi

cd "$REPO_ROOT"
if ! STATIC_DIR="$(realpath -m -- "$STATIC_DIR")"; then
  preflight_failure 1 "resolve static directory"
fi
if [[ "$STATIC_DIR" == "/" || "$STATIC_DIR" == "$REPO_ROOT" ||
  "$REPO_ROOT" == "$STATIC_DIR/"* || "${STATIC_DIR##*/}" != "staticfiles" ]]; then
  echo "STATIC_DIR must be a dedicated staticfiles directory, not a parent or repository root."
  preflight_failure 1 "validate static directory"
fi

echo "Deploying branch '$BRANCH' to environment '$ENV'"

echo "Authenticating Docker to ECR..."
if aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
  :
else
  preflight_failure "$?" "authenticate Docker to ECR"
fi

if ! docker info > /dev/null; then
  echo "Docker Engine is unavailable; deployment cannot continue."
  preflight_failure 1 "check Docker Engine"
fi

if ! aws ecr describe-images \
  --repository-name "$ECR_REPOSITORY" \
  --image-ids "imageTag=${IMAGE_TAG}" \
  --region "$AWS_REGION" > /dev/null; then
  echo "Required image tag '${IMAGE_TAG}' was not found in ECR; deployment cannot continue."
  preflight_failure 1 "verify requested ECR image"
fi

APP_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
export IMAGE_TAG APP_IMAGE

echo "Image being deployed: $APP_IMAGE"

PREVIOUS_IMAGE_ID=""
PREVIOUS_IMAGE_REFERENCE=""
PREVIOUS_IMAGE_AVAILABLE=0
if PREVIOUS_IMAGE_DETAILS="$(docker inspect \
  --format '{{.Image}} {{.Config.Image}}' "$APP_SERVICE" 2>/dev/null)"; then
  read -r PREVIOUS_IMAGE_ID PREVIOUS_IMAGE_REFERENCE <<< "$PREVIOUS_IMAGE_DETAILS"
  if [[ ! "$PREVIOUS_IMAGE_ID" =~ ^sha256:[0-9a-f]{64}$ || -z "$PREVIOUS_IMAGE_REFERENCE" ]]; then
    echo "Could not safely identify the image used by the current app container."
    preflight_failure 1 "record previous app image"
  fi
  PREVIOUS_IMAGE_AVAILABLE=1
  echo "Recorded previous image reference: $PREVIOUS_IMAGE_REFERENCE"
  echo "Recorded previous Docker image ID: $PREVIOUS_IMAGE_ID"
else
  if ! RUNNING_CONTAINERS="$(docker ps -a --format '{{.Names}}')"; then
    preflight_failure 1 "inspect existing containers"
  fi
  if grep -Fxq "$APP_SERVICE" <<< "$RUNNING_CONTAINERS"; then
    echo "The existing app container could not be inspected; refusing to deploy without a rollback target."
    preflight_failure 1 "record previous app image"
  fi
  echo "No previous app container exists; rollback will be unavailable if deployment fails."
fi

if ! STATIC_SNAPSHOT_ROOT="$(mktemp -d /tmp/uptime-watch-static.XXXXXX)"; then
  preflight_failure 1 "create static-file snapshot"
fi
if ! mkdir -p "$STATIC_DIR" "$STATIC_SNAPSHOT_ROOT/staticfiles"; then
  rm -rf -- "$STATIC_SNAPSHOT_ROOT"
  preflight_failure 1 "prepare static-file snapshot"
fi
if ! cp -a "$STATIC_DIR/." "$STATIC_SNAPSHOT_ROOT/staticfiles/"; then
  echo "Could not snapshot the production static files; deployment cannot continue."
  rm -rf -- "$STATIC_SNAPSHOT_ROOT"
  preflight_failure 1 "copy static-file snapshot"
fi

cleanup_static_snapshot() {
  local exit_status=$?
  trap - EXIT
  if [[ -n "${STATIC_SNAPSHOT_ROOT:-}" && -d "$STATIC_SNAPSHOT_ROOT" ]]; then
    if ! rm -rf -- "$STATIC_SNAPSHOT_ROOT"; then
      echo "Could not remove temporary static-file snapshot: $STATIC_SNAPSHOT_ROOT" >&2
    fi
  fi
  exit "$exit_status"
}
trap cleanup_static_snapshot EXIT

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

restore_static_snapshot() {
  if [[ ! -d "$STATIC_SNAPSHOT_ROOT/staticfiles" ]]; then
    echo "Static-file snapshot is missing." >&2
    return 1
  fi

  mkdir -p "$STATIC_DIR" || return $?
  find "$STATIC_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + || return $?
  cp -a "$STATIC_SNAPSHOT_ROOT/staticfiles/." "$STATIC_DIR/" || return $?
  echo "Previous static files restored."
}

run_new_deployment() {
  CURRENT_STAGE="pull new image"
  echo "Pulling app image from ECR: $APP_IMAGE"
  docker compose -f "$COMPOSE_FILE" pull "$APP_SERVICE" || return $?

  CURRENT_STAGE="start new containers"
  echo "Starting containers from pulled image..."
  docker compose -f "$COMPOSE_FILE" up -d || return $?

  CURRENT_STAGE="run database migrations"
  echo "Running database migrations..."
  docker compose -f "$COMPOSE_FILE" exec -T "$APP_SERVICE" python manage.py migrate || return $?

  CURRENT_STAGE="collect static files"
  echo "Collecting static files..."
  STATIC_MUTATION_STARTED="yes"
  docker compose -f "$COMPOSE_FILE" exec -T "$APP_SERVICE" python manage.py collectstatic --clear --no-input || return $?

  CURRENT_STAGE="verify Django readiness"
  wait_for_app_health || return $?

  CURRENT_STAGE="verify Nginx health"
  verify_nginx_health || return $?

  CURRENT_STAGE="verify public HTTPS readiness"
  verify_public_health || return $?
}

handle_deployment_failure() {
  local failure_status="$1"
  local failure_stage="$2"

  trap '' HUP INT TERM
  FAILURE_STATUS="$failure_status"
  FAILURE_STAGE="$failure_stage"
  DEPLOYMENT_OUTCOME="deployment_failed"
  echo "New deployment failed during '${FAILURE_STAGE}' (exit status ${FAILURE_STATUS})." >&2
  echo "Attempted image: $ATTEMPTED_IMAGE" >&2
  echo "Previous image reference: ${PREVIOUS_IMAGE_REFERENCE:-none}" >&2
  echo "Previous image ID: ${PREVIOUS_IMAGE_ID:-none}" >&2

  if (( PREVIOUS_IMAGE_AVAILABLE == 0 )); then
    ROLLBACK_ATTEMPTED="no"
    ROLLBACK_OUTCOME="unavailable"
    APP_RESTORE_OUTCOME="unavailable"
    echo "ROLLBACK UNAVAILABLE: no previous application image was recorded." >&2
    if [[ "$STATIC_MUTATION_STARTED" == "yes" ]]; then
      if restore_static_snapshot; then
        STATIC_RESTORE_OUTCOME="succeeded"
      else
        STATIC_RESTORE_OUTCOME="failed"
        echo "Static-file restoration also failed; the deployed static directory may be incomplete." >&2
      fi
    fi
    emit_deployment_summary
    exit "$FAILURE_STATUS"
  fi

  ROLLBACK_ATTEMPTED="yes"
  ROLLBACK_OUTCOME="failed"
  ROLLBACK_IMAGE_REF="${ECR_REGISTRY}/${ECR_REPOSITORY}:rollback-${PREVIOUS_IMAGE_ID#sha256:}"
  ROLLBACK_FAILURES=()
  APP_RESTORE_FAILURES=()
  ROLLBACK_START_SUCCEEDED="no"

  echo "Attempting rollback to recorded image ID: $PREVIOUS_IMAGE_ID"
  echo "Rollback Compose image reference: $ROLLBACK_IMAGE_REF"

  if [[ "$STATIC_MUTATION_STARTED" == "yes" ]]; then
    if restore_static_snapshot; then
      STATIC_RESTORE_OUTCOME="succeeded"
    else
      STATIC_RESTORE_OUTCOME="failed"
      ROLLBACK_FAILURES+=("static-file restore failed")
    fi
  else
    STATIC_RESTORE_OUTCOME="not_needed"
    echo "Static-file restoration not needed; collectstatic was not started."
  fi

  if docker image tag "$PREVIOUS_IMAGE_ID" "$ROLLBACK_IMAGE_REF"; then
    APP_IMAGE="$ROLLBACK_IMAGE_REF"
    export APP_IMAGE
    if docker compose -f "$COMPOSE_FILE" up -d; then
      ROLLBACK_START_SUCCEEDED="yes"
      echo "Compose started the recorded previous application image."
    else
      APP_RESTORE_FAILURES+=("Compose failed to start the recorded previous application image")
      ROLLBACK_FAILURES+=("Compose failed to start the recorded previous application image")
    fi
  else
    APP_RESTORE_FAILURES+=("could not tag the recorded previous application image")
    ROLLBACK_FAILURES+=("could not tag the recorded previous application image")
  fi

  if ! wait_for_app_health; then
    APP_RESTORE_FAILURES+=("Django readiness verification failed")
    ROLLBACK_FAILURES+=("Django readiness verification failed")
  fi
  if ! verify_nginx_health; then
    APP_RESTORE_FAILURES+=("Nginx health verification failed")
    ROLLBACK_FAILURES+=("Nginx health verification failed")
  fi
  if ! verify_public_health; then
    APP_RESTORE_FAILURES+=("public HTTPS readiness verification failed")
    ROLLBACK_FAILURES+=("public HTTPS readiness verification failed")
  fi

  CURRENT_APP_IMAGE_ID=""
  if CURRENT_APP_IMAGE_ID="$(docker inspect --format '{{.Image}}' "$APP_SERVICE" 2>/dev/null)" &&
    [[ "$CURRENT_APP_IMAGE_ID" == "$PREVIOUS_IMAGE_ID" ]]; then
    echo "Verified running app image ID: $CURRENT_APP_IMAGE_ID"
  else
    APP_RESTORE_FAILURES+=("running app image ID does not match the recorded previous image")
    ROLLBACK_FAILURES+=("running app image ID does not match the recorded previous image")
  fi

  if [[ "$ROLLBACK_START_SUCCEEDED" == "yes" ]] && (( ${#APP_RESTORE_FAILURES[@]} == 0 )); then
    APP_RESTORE_OUTCOME="succeeded"
    RESTORED_IMAGE_REFERENCE="$PREVIOUS_IMAGE_REFERENCE"
  else
    APP_RESTORE_OUTCOME="failed"
  fi

  if (( ${#ROLLBACK_FAILURES[@]} == 0 )); then
    ROLLBACK_OUTCOME="succeeded"
    echo "ROLLBACK SUCCEEDED: restored image reference '$PREVIOUS_IMAGE_REFERENCE' (ID $PREVIOUS_IMAGE_ID)."
    emit_deployment_summary
    exit "$FAILURE_STATUS"
  fi

  echo "ROLLBACK FAILED for image ID $PREVIOUS_IMAGE_ID:" >&2
  printf ' - %s\n' "${ROLLBACK_FAILURES[@]}" >&2
  echo "Production may not be healthy; operator attention is required." >&2
  emit_deployment_summary
  exit "$FAILURE_STATUS"
}

DEPLOYMENT_OUTCOME="deployment_succeeded"
ROLLBACK_ATTEMPTED="no"
ROLLBACK_OUTCOME="not_attempted"
RESTORED_IMAGE_REFERENCE=""
FAILURE_STAGE=""
FAILURE_STATUS=0
CURRENT_STAGE="deployment"
trap 'handle_deployment_failure 129 "received SIGHUP during ${CURRENT_STAGE}"' HUP
trap 'handle_deployment_failure 130 "received SIGINT during ${CURRENT_STAGE}"' INT
trap 'handle_deployment_failure 143 "received SIGTERM during ${CURRENT_STAGE}"' TERM

if run_new_deployment; then
  echo "Deployment for '$BRANCH' completed successfully."
  emit_deployment_summary
  exit 0
else
  handle_deployment_failure "$?" "$CURRENT_STAGE"
fi
