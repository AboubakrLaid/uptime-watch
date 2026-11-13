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
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${IMAGE_TAG:-}"
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
EOF
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

echo "Deployment for '$BRANCH' completed successfully."
