#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
BIN_DIR="$TEST_ROOT/bin"
mkdir -p "$BIN_DIR"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

PREVIOUS_IMAGE_ID="sha256:$(printf 'a%.0s' {1..64})"
NEW_IMAGE_ID="sha256:$(printf 'b%.0s' {1..64})"
PREVIOUS_IMAGE_REFERENCE="373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:upwatch-back-20261120-120000-abcdef0"
NEW_IMAGE_TAG="upwatch-back-20261121-120000-1234567"
APP_CONTAINER="uptime-watch-app"

cat > "$BIN_DIR/aws" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *"get-login-password"*) printf 'token\n' ;;
  *"describe-images"*)
    [[ "${MOCK_IMAGE_EXISTS:-yes}" == "yes" ]]
    printf '%s\n' "$*" >> "$MOCK_AWS_COMMAND_LOG"
    ;;
  *)
    echo "Unexpected aws invocation: $*" >&2
    exit 2
    ;;
esac
SH

cat > "$BIN_DIR/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_COMMAND_LOG"

if [[ "$1" == "login" ]]; then
  cat > /dev/null
  exit 0
fi

if [[ "$1" == "info" ]]; then
  exit 0
fi

if [[ "$1" == "inspect" ]]; then
  format="$3"
  if [[ "$format" == *".Config.Image"* ]]; then
    if [[ "${MOCK_HAS_PREVIOUS:-yes}" != "yes" ]]; then
      exit 1
    fi
    IFS='|' read -r image_id image_ref < "$MOCK_CURRENT_IMAGE_FILE"
    printf '%s %s\n' "$image_id" "$image_ref"
    exit 0
  fi

  IFS='|' read -r image_id _ < "$MOCK_CURRENT_IMAGE_FILE"
  if [[ "$format" == "{{.Image}}" ]]; then
    printf '%s\n' "$image_id"
    exit 0
  fi
  if [[ "$image_id" == "$MOCK_NEW_IMAGE_ID" && "${MOCK_FAIL_NEW_HEALTH:-no}" == "yes" ]]; then
    printf 'unhealthy\n'
  elif [[ "$image_id" == "$MOCK_PREVIOUS_IMAGE_ID" && "${MOCK_FAIL_ROLLBACK_HEALTH:-no}" == "yes" ]]; then
    printf 'unhealthy\n'
  else
    printf 'healthy\n'
  fi
  exit 0
fi

if [[ "$1" == "ps" ]]; then
  if [[ "${MOCK_HAS_PREVIOUS:-yes}" == "yes" ]]; then
    printf '%s\n' "$APP_CONTAINER"
  fi
  exit 0
fi

if [[ "$1" == "image" && "$2" == "tag" ]]; then
  exit 0
fi

if [[ "$1" != "compose" ]]; then
  echo "Unexpected docker invocation: $*" >&2
  exit 2
fi
shift
while [[ "$#" -gt 0 && "$1" == "-f" ]]; do
  shift 2
done

operation="$1"
shift
case "$operation" in
  pull)
    if [[ "${MOCK_FAIL_STAGE:-}" == "pull" ]]; then
      exit 31
    fi
    ;;
  up)
    printf 'APP_IMAGE=%s\n' "${APP_IMAGE:-}" >> "$MOCK_COMMAND_LOG"
    if [[ "${APP_IMAGE:-}" == *":rollback-"* ]]; then
      if [[ "${MOCK_FAIL_ROLLBACK_START:-no}" == "yes" ]]; then
        exit 41
      fi
      printf '%s|%s\n' "$MOCK_PREVIOUS_IMAGE_ID" "$APP_IMAGE" > "$MOCK_CURRENT_IMAGE_FILE"
    else
      if [[ "${MOCK_FAIL_STAGE:-}" == "up" ]]; then
        exit 33
      fi
      printf '%s|%s\n' "$MOCK_NEW_IMAGE_ID" "$APP_IMAGE" > "$MOCK_CURRENT_IMAGE_FILE"
    fi
    ;;
  exec)
    shift
    if [[ "$1" == "$APP_CONTAINER" ]]; then
      shift
      if [[ "${MOCK_FAIL_STAGE:-}" == "migrate" && "$*" == *"manage.py migrate"* ]]; then
        exit 32
      fi
      if [[ "$*" == *"manage.py collectstatic"* ]]; then
        printf 'new static content\n' > "$MOCK_STATIC_DIR/site.css"
        printf 'new static asset\n' > "$MOCK_STATIC_DIR/new-file.css"
        if [[ "${MOCK_FAIL_STAGE:-}" == "collectstatic" ]]; then
          exit 42
        fi
      fi
    elif [[ "$1" == "nginx" ]]; then
      printf '200'
    else
      echo "Unexpected compose exec service: $1" >&2
      exit 2
    fi
    ;;
  ps|logs)
    ;;
  *)
    echo "Unexpected docker compose operation: $operation $*" >&2
    exit 2
    ;;
esac
SH

cat > "$BIN_DIR/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '\n200'
SH

cat > "$BIN_DIR/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_GIT_FAIL:-}" == "$1" ]]; then
  exit 17
fi
exit 0
SH

chmod +x "$BIN_DIR/aws" "$BIN_DIR/docker" "$BIN_DIR/curl" "$BIN_DIR/git"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "did not expect '$unexpected' in $file"
  fi
}

reset_case() {
  local name="$1"
  CASE_DIR="$TEST_ROOT/$name"
  mkdir -p "$CASE_DIR/home" "$CASE_DIR/staticfiles"
  : > "$CASE_DIR/compose.yml"
  printf 'old static content\n' > "$CASE_DIR/staticfiles/site.css"
  MOCK_CURRENT_IMAGE_FILE="$CASE_DIR/current-image"
  MOCK_COMMAND_LOG="$CASE_DIR/commands.log"
  MOCK_AWS_COMMAND_LOG="$CASE_DIR/aws-commands.log"
  : > "$MOCK_AWS_COMMAND_LOG"
  MOCK_STATIC_DIR="$CASE_DIR/staticfiles"
  DEPLOY_LOCK_FILE="$CASE_DIR/deploy.lock"
  MOCK_PREVIOUS_IMAGE_REFERENCE="$PREVIOUS_IMAGE_REFERENCE"
  printf '%s|%s\n' "$PREVIOUS_IMAGE_ID" "$MOCK_PREVIOUS_IMAGE_REFERENCE" > "$MOCK_CURRENT_IMAGE_FILE"
  : > "$MOCK_COMMAND_LOG"
  MOCK_HAS_PREVIOUS="yes"
  MOCK_FAIL_STAGE=""
  MOCK_FAIL_NEW_HEALTH="no"
  MOCK_FAIL_ROLLBACK_HEALTH="no"
  MOCK_FAIL_ROLLBACK_START="no"
  MOCK_IMAGE_EXISTS="yes"
  OUTPUT_FILE="$CASE_DIR/output.log"
}

run_deploy() {
  local status
  local image_tag="${1:-$NEW_IMAGE_TAG}"
  set +e
  PATH="$BIN_DIR:$PATH" \
    HOME="$CASE_DIR/home" \
    DEPLOY_LOCK_FILE="$CASE_DIR/deploy.lock" \
    COMPOSE_FILE="$CASE_DIR/compose.yml" \
    STATIC_DIR="$MOCK_STATIC_DIR" \
    MOCK_CURRENT_IMAGE_FILE="$MOCK_CURRENT_IMAGE_FILE" \
    MOCK_COMMAND_LOG="$MOCK_COMMAND_LOG" \
    MOCK_STATIC_DIR="$MOCK_STATIC_DIR" \
    APP_CONTAINER="$APP_CONTAINER" \
    MOCK_PREVIOUS_IMAGE_ID="$PREVIOUS_IMAGE_ID" \
    MOCK_PREVIOUS_IMAGE_REFERENCE="$MOCK_PREVIOUS_IMAGE_REFERENCE" \
    MOCK_NEW_IMAGE_ID="$NEW_IMAGE_ID" \
    MOCK_AWS_COMMAND_LOG="$MOCK_AWS_COMMAND_LOG" \
    MOCK_HAS_PREVIOUS="$MOCK_HAS_PREVIOUS" \
    MOCK_FAIL_STAGE="$MOCK_FAIL_STAGE" \
    MOCK_FAIL_NEW_HEALTH="$MOCK_FAIL_NEW_HEALTH" \
    MOCK_FAIL_ROLLBACK_HEALTH="$MOCK_FAIL_ROLLBACK_HEALTH" \
    MOCK_FAIL_ROLLBACK_START="$MOCK_FAIL_ROLLBACK_START" \
    MOCK_IMAGE_EXISTS="$MOCK_IMAGE_EXISTS" \
    APP_HEALTH_TIMEOUT_SECONDS=1 \
    APP_HEALTH_POLL_INTERVAL_SECONDS=1 \
    NGINX_HEALTH_RETRIES=1 \
    NGINX_HEALTH_RETRY_INTERVAL_SECONDS=1 \
    NGINX_HEALTH_REQUEST_TIMEOUT_SECONDS=1 \
    PUBLIC_HEALTH_RETRIES=1 \
    PUBLIC_HEALTH_RETRY_INTERVAL_SECONDS=1 \
    PUBLIC_HEALTH_REQUEST_TIMEOUT_SECONDS=1 \
    bash "$REPO_ROOT/deploy.sh" --image-tag "$image_tag" > "$OUTPUT_FILE" 2>&1
  status=$?
  set -e
  return "$status"
}

reset_case success
if run_deploy; then
  :
else
  fail "successful deployment exited nonzero: $(<"$OUTPUT_FILE")"
fi
assert_contains "$OUTPUT_FILE" "DEPLOYMENT_OUTCOME=deployment_succeeded"
assert_contains "$OUTPUT_FILE" "ROLLBACK_ATTEMPTED=no"
assert_contains "$OUTPUT_FILE" "ATTEMPTED_IMAGE=373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:$NEW_IMAGE_TAG"
assert_contains "$MOCK_COMMAND_LOG" "State.Health.Status"
assert_contains "$MOCK_COMMAND_LOG" "nginx"
IFS='|' read -r current_id _ < "$MOCK_CURRENT_IMAGE_FILE"
[[ "$current_id" == "$NEW_IMAGE_ID" ]] || fail "success did not leave the new image running"
[[ "$(<"$MOCK_STATIC_DIR/site.css")" == "new static content" ]] || fail "success did not collect static files"

reset_case latest-tag
if run_deploy latest; then
  :
else
  fail "latest deployment exited nonzero"
fi
assert_contains "$OUTPUT_FILE" "ATTEMPTED_IMAGE=373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:latest"
assert_contains "$MOCK_AWS_COMMAND_LOG" "imageTag=latest"
assert_contains "$MOCK_COMMAND_LOG" "APP_IMAGE=373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:latest"

reset_case explicit-custom-tag
CUSTOM_IMAGE_TAG="release-canary_1"
if run_deploy "$CUSTOM_IMAGE_TAG"; then
  :
else
  fail "explicit custom-tag deployment exited nonzero"
fi
assert_contains "$OUTPUT_FILE" "ATTEMPTED_IMAGE=373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:$CUSTOM_IMAGE_TAG"
assert_contains "$MOCK_AWS_COMMAND_LOG" "imageTag=$CUSTOM_IMAGE_TAG"
assert_contains "$MOCK_COMMAND_LOG" "APP_IMAGE=373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:$CUSTOM_IMAGE_TAG"

reset_case start-failure-before-static
MOCK_FAIL_STAGE="up"
if run_deploy; then
  fail "container start failure unexpectedly exited successfully"
else
  status=$?
fi
[[ "$status" -eq 33 ]] || fail "container start failure did not preserve its original status"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=succeeded"
assert_contains "$OUTPUT_FILE" "APP_RESTORE_OUTCOME=succeeded"
assert_contains "$OUTPUT_FILE" "STATIC_RESTORE_OUTCOME=not_needed"
assert_contains "$OUTPUT_FILE" "Static-file restoration not needed"
assert_contains "$OUTPUT_FILE" "RESTORED_IMAGE_REFERENCE=$PREVIOUS_IMAGE_REFERENCE"
IFS='|' read -r current_id _ < "$MOCK_CURRENT_IMAGE_FILE"
[[ "$current_id" == "$PREVIOUS_IMAGE_ID" ]] || fail "startup failure did not restore the previous image"

reset_case rollback-success
MOCK_FAIL_STAGE="collectstatic"
if run_deploy; then
  fail "failed deployment unexpectedly exited successfully"
else
  status=$?
fi
[[ "$status" -eq 42 ]] || fail "expected original collectstatic status 42, got $status"
assert_contains "$OUTPUT_FILE" "FAILURE_STAGE=collect static files"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=succeeded"
assert_contains "$OUTPUT_FILE" "ROLLBACK SUCCEEDED"
assert_not_contains "$OUTPUT_FILE" ":latest"
[[ "$(<"$MOCK_STATIC_DIR/site.css")" == "old static content" ]] || fail "rollback did not restore old static files"
[[ ! -e "$MOCK_STATIC_DIR/new-file.css" ]] || fail "rollback left new static files behind"
IFS='|' read -r current_id _ < "$MOCK_CURRENT_IMAGE_FILE"
[[ "$current_id" == "$PREVIOUS_IMAGE_ID" ]] || fail "rollback did not restore the previous image ID"

reset_case healthcheck-rollback
MOCK_FAIL_NEW_HEALTH="yes"
if run_deploy; then
  fail "unhealthy new deployment unexpectedly exited successfully"
else
  status=$?
fi
[[ "$status" -ne 0 ]] || fail "healthcheck failure returned success"
assert_contains "$OUTPUT_FILE" "FAILURE_STAGE=verify Django readiness"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=succeeded"
[[ "$(<"$MOCK_STATIC_DIR/site.css")" == "old static content" ]] || fail "healthcheck rollback did not restore static files"

reset_case migration-failure
MOCK_FAIL_STAGE="migrate"
if run_deploy; then
  fail "migration failure unexpectedly exited successfully"
else
  status=$?
fi
[[ "$status" -eq 32 ]] || fail "migration failure did not preserve its original status"
assert_contains "$OUTPUT_FILE" "FAILURE_STAGE=run database migrations"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=succeeded"
IFS='|' read -r current_id _ < "$MOCK_CURRENT_IMAGE_FILE"
[[ "$current_id" == "$PREVIOUS_IMAGE_ID" ]] || fail "migration failure did not restore the previous image"

reset_case rollback-failure
MOCK_FAIL_STAGE="collectstatic"
MOCK_FAIL_ROLLBACK_HEALTH="yes"
if run_deploy; then
  fail "failed rollback unexpectedly exited successfully"
else
  status=$?
fi
[[ "$status" -eq 42 ]] || fail "rollback failure replaced original status: $status"
assert_contains "$OUTPUT_FILE" "DEPLOYMENT_OUTCOME=deployment_failed"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=failed"
assert_contains "$OUTPUT_FILE" "Django readiness verification failed"
assert_contains "$OUTPUT_FILE" "collect static files"

reset_case rollback-start-failure
MOCK_FAIL_STAGE="collectstatic"
MOCK_FAIL_ROLLBACK_START="yes"
if run_deploy; then
  fail "rollback start failure unexpectedly exited successfully"
else
  status=$?
fi
[[ "$status" -eq 42 ]] || fail "rollback start failure replaced original status"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=failed"
assert_contains "$OUTPUT_FILE" "Compose failed to start the recorded previous application image"

reset_case previous-latest
MOCK_PREVIOUS_IMAGE_REFERENCE="373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:latest"
printf '%s|%s\n' "$PREVIOUS_IMAGE_ID" "$MOCK_PREVIOUS_IMAGE_REFERENCE" > "$MOCK_CURRENT_IMAGE_FILE"
MOCK_FAIL_STAGE="collectstatic"
if run_deploy; then
  fail "deployment using a previous latest reference unexpectedly succeeded"
else
  status=$?
fi
[[ "$status" -eq 42 ]] || fail "latest rollback test replaced original status"
assert_contains "$OUTPUT_FILE" "Rollback Compose image reference: 373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:rollback-"
assert_not_contains "$MOCK_COMMAND_LOG" "APP_IMAGE=373080580380.dkr.ecr.eu-west-3.amazonaws.com/uptime-watch:latest"

reset_case no-previous-image
MOCK_HAS_PREVIOUS="no"
MOCK_FAIL_STAGE="collectstatic"
if run_deploy; then
  fail "first deployment failure unexpectedly exited successfully"
else
  status=$?
fi
[[ "$status" -eq 42 ]] || fail "first deployment did not preserve the failure status"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=unavailable"
assert_contains "$OUTPUT_FILE" "ROLLBACK UNAVAILABLE"
assert_not_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=succeeded"
[[ "$(<"$MOCK_STATIC_DIR/site.css")" == "old static content" ]] || fail "first-deployment failure did not restore static files"

reset_case preflight-failure
MOCK_IMAGE_EXISTS="no"
if run_deploy; then
  fail "missing ECR image unexpectedly deployed"
else
  status=$?
fi
[[ "$status" -ne 0 ]] || fail "missing ECR image returned success"
assert_not_contains "$MOCK_COMMAND_LOG" "compose pull"
assert_contains "$OUTPUT_FILE" "Use 'latest' or a tag that contains both letters and digits."
assert_contains "$OUTPUT_FILE" "ROLLBACK_ATTEMPTED=no"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=not_attempted"

reset_case lock-contention
exec {LOCK_FD}>"$DEPLOY_LOCK_FILE"
flock -n "$LOCK_FD"
if run_deploy; then
  fail "concurrent deployment unexpectedly acquired the lock"
else
  status=$?
fi
exec {LOCK_FD}>&-
[[ "$status" -eq 75 ]] || fail "lock contention returned $status instead of 75"
assert_contains "$OUTPUT_FILE" "Another deployment is already in progress"
assert_not_contains "$MOCK_COMMAND_LOG" "compose pull"

reset_case make-lock-contention
exec {LOCK_FD}>"$DEPLOY_LOCK_FILE"
flock -n "$LOCK_FD"
set +e
DEPLOY_LOCK_FILE="$DEPLOY_LOCK_FILE" make -C "$REPO_ROOT" deploy IMAGE_TAG="$NEW_IMAGE_TAG" > "$OUTPUT_FILE" 2>&1
status=$?
set -e
exec {LOCK_FD}>&-
[[ "$status" -ne 0 ]] || fail "Makefile lock contention returned success"
assert_contains "$OUTPUT_FILE" "Another deployment is already in progress"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=not_attempted"
assert_not_contains "$OUTPUT_FILE" "Refreshing repo"

reset_case checkout-failure
set +e
PATH="$BIN_DIR:$PATH" \
  DEPLOY_LOCK_FILE="$DEPLOY_LOCK_FILE" \
  MOCK_GIT_FAIL="fetch" \
  make -C "$REPO_ROOT" deploy IMAGE_TAG="$NEW_IMAGE_TAG" > "$OUTPUT_FILE" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "checkout failure returned success"
assert_contains "$OUTPUT_FILE" "FAILURE_STAGE=fetch main"
assert_contains "$OUTPUT_FILE" "ROLLBACK_OUTCOME=not_attempted"
assert_not_contains "$OUTPUT_FILE" "./deploy.sh"

echo "All deployment rollback tests passed."
