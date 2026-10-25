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

## Notes

- The project is intentionally minimal and ready for progressively adding DevOps and monitoring learning notions.
