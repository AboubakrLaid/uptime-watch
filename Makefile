install:
	pip3 install -r requirements.txt

IMAGE_TAG ?= latest

makemigrations:
	python3 manage.py makemigrations

migrate:
	python3 manage.py migrate

resetdb:
	python3 manage.py migrate --noinput && \
	python3 manage.py flush --noinput && \
	python3 manage.py loaddata fixtures/websites.json

up:
	docker compose up -d

deploy:
	@command -v flock >/dev/null 2>&1 || { echo "flock is required to prevent concurrent deployments."; printf 'DEPLOYMENT_OUTCOME=deployment_failed\nROLLBACK_ATTEMPTED=no\nROLLBACK_OUTCOME=not_attempted\nATTEMPTED_IMAGE=%s\nFAILURE_STAGE=check flock dependency\nFAILURE_STATUS=1\n' "$(IMAGE_TAG)"; exit 1; }
	@flock -n -E 75 "$${DEPLOY_LOCK_FILE:-$$HOME/.uptime-watch-deploy.lock}" bash -c '\
		set -euo pipefail; \
		IMAGE_TAG_ARG="$$1"; \
		predeploy_failure() { \
			status="$$1"; \
			stage="$$2"; \
			echo "Deployment preflight failed during '\''$$stage'\'' (exit status $$status)." >&2; \
			printf "DEPLOYMENT_OUTCOME=deployment_failed\nROLLBACK_ATTEMPTED=no\nROLLBACK_OUTCOME=not_attempted\nATTEMPTED_IMAGE=%s\nFAILURE_STAGE=%s\nFAILURE_STATUS=%s\n" "$$IMAGE_TAG_ARG" "$$stage" "$$status"; \
			exit "$$status"; \
		}; \
		echo "Refreshing repo before running the deploy script..."; \
		if git fetch origin main --prune; then :; else status=$$?; predeploy_failure "$$status" "fetch main"; fi; \
		if git checkout main; then :; else status=$$?; predeploy_failure "$$status" "checkout main"; fi; \
		if git reset --hard origin/main; then :; else status=$$?; predeploy_failure "$$status" "refresh checkout"; fi; \
		if git pull --ff-only origin main; then :; else status=$$?; predeploy_failure "$$status" "fast-forward main"; fi; \
		UPWATCH_DEPLOY_LOCK_HELD=1 ./deploy.sh --image-tag "$$1" \
	' _ "$(IMAGE_TAG)" || { status=$$?; if [ "$$status" -eq 75 ]; then echo "Another deployment is already in progress; refusing to change production." >&2; printf 'DEPLOYMENT_OUTCOME=deployment_failed\nROLLBACK_ATTEMPTED=no\nROLLBACK_OUTCOME=not_attempted\nATTEMPTED_IMAGE=%s\nFAILURE_STAGE=deployment lock\nFAILURE_STATUS=75\n' "$(IMAGE_TAG)"; fi; exit "$$status"; }

run:
	python3 manage.py runserver_plus
