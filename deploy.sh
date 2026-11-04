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
APP_IMAGE="${APP_IMAGE:-}"
IMAGE_TAG="${IMAGE_TAG:-}"

usage() {
  cat <<EOF
Usage: ./deploy.sh [options]

Options:
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

if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
fi

git fetch origin "$BRANCH" --prune
git reset --hard "origin/$BRANCH"
git pull --ff-only origin "$BRANCH"

if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG="$(aws ecr describe-images \
    --repository-name "$ECR_REPOSITORY" \
    --region "$AWS_REGION" \
    --query 'sort_by(imageDetails, &imagePushedAt)[-1].imageTags[0]' \
    --output text 2>/dev/null || echo latest)"
fi

if [[ -z "$APP_IMAGE" ]]; then
  APP_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
fi

export APP_IMAGE

echo "Pulling app image from ECR: $APP_IMAGE"
docker compose -f "$COMPOSE_FILE" pull "$APP_SERVICE"

echo "Starting containers from pulled image..."
docker compose -f "$COMPOSE_FILE" up -d

echo "Running database migrations..."
docker compose -f "$COMPOSE_FILE" exec -T "$APP_SERVICE" python manage.py migrate

echo "Collecting static files..."
docker compose -f "$COMPOSE_FILE" exec -T "$APP_SERVICE" python manage.py collectstatic --clear --no-input

echo "Deployment for '$BRANCH' completed successfully."
