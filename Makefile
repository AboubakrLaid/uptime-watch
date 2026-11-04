install:
	pip3 install -r requirements.txt

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
	@echo "Refreshing repo, then running deploy script..."
	git fetch origin main --prune
	git checkout main
	git reset --hard origin/main
	git pull --ff-only origin main
	./deploy.sh

run:
	python3 manage.py runserver_plus
