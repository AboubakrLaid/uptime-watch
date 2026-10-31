# DevOps Learning Playground

This project is my playground for learning DevOps. It is where I practice the workflows, automation, and operational thinking behind modern software delivery.

The application is a small website-availability tracking service, inspired by tools like Uptime Kuma. It serves as a learning substrate for understanding monitoring, automation, and deployment-oriented engineering practices.

## What I have built so far

### 1. Git workflow automation

- Built a custom Push-new-feature workflow in `.github/skills/push-new-feature/SKILL.md`
- Detects the current working directory
- Suggests a branch name and commit message
- Helps structure the feature push flow

### 2. CI for automated validation

- Implemented a CI pipeline in `.github/workflows/pytest.yml`
- Runs validation automatically on code changes
- Helps enforce quality gates before merge
- Builds confidence through repeatable checks

### 3. Health checks and startup validation

- health check
  - `/health/ready/` runs a real DB query `SELECT 1` to make sure the database is usable, not only reachable
  - `/health/deep/` is used to check whether other services are reachable, such as Redis, Celery, or Elasticsearch, and can be expanded later if needed
  - A health check should fail for the same reasons a real request fails, not just because the process is running
  - If the app cannot use its dependencies, it should return `503` instead of pretending to be healthy
- startup validation
  - It goes beyond checking whether the database is reachable; it confirms the database is actually usable
  - It makes sure the app can connect to the database and execute a real query during startup
  - This helps fail fast during deployment instead of starting a service that looks alive but is not ready to serve traffic

### 4. Basic deployment

- Added Nginx to the Docker Compose setup and made it the entry point for the application.
- Kept the API service internal and exposed it only through Nginx.
- Configured SSL for secure HTTPS access.
- Added Nginx logs for access, errors, and related operational visibility.
- Linked the EC2 instance to an Elastic IP so the domain keeps pointing to the same public address even if the instance is stopped and restarted.
- The deployment process is still manual:
  1. Connect to the EC2 instance over SSH.
  2. Install the required system packages and tools, including Docker.
  3. Clone the repository from GitHub.
  4. Configure the application environment variables in the .env file.
  5. Start the Docker containers.
  6. Run the database migrations.
- The architecture now runs through Docker Compose with three containers: Nginx, API, and database. They communicate through a Docker network, and Nginx is the only public entry point to the application.

![Uptime Watch Architecture and Deployment Flow](pics/Uptime%20Watch%20Architecture%20and%20Deployment%20Flow.png)

## Notes

- The project is intentionally minimal and ready for progressively adding DevOps and monitoring learning notions.
