---
name: devops-roadmap
description: "Use when: reviewing the project as a DevOps learning journey, checking what has already been achieved, deciding what should come next, and balancing the user’s preferred topic with the missing foundations a strong DevOps engineer still needs."
---

# DevOps Learning Roadmap

Use this skill when the user wants to assess how far they have progressed in becoming a DevOps engineer, based on the work already present in the project, and to decide what should happen next.

## Goal

Review the repository as evidence of the user’s learning journey and produce a practical learning plan that:

1. identifies the DevOps practices already built
2. identifies the missing fundamentals that still matter
3. evaluates the user’s suggested next topic
4. recommends the best next step, while treating the user’s idea as input, not a guarantee

This is not a generic roadmap generator. It must be grounded in the actual project state and in DevOps maturity progression.

## Required workflow

### 1. Analyze the repository as evidence

Inspect the project and infer what the user has already achieved.

Look for evidence such as:

- Git workflow automation in `.github/skills/`
- CI validation in `.github/workflows/`
- Container setup in `Dockerfile` and `docker-compose.yml`
- Environment configuration in `envs/` and `.env`
- App and service structure under `main/` and `config/`
- Automated tests under `tests/`
- Deployment or operational docs in the README and project config

Treat the presence of these artifacts as signs of learned skills.

### 2. Map the project to DevOps maturity stages

Classify the project across a realistic DevOps progression:

- Git hygiene and collaboration
- CI quality gates
- Local development environment reproducibility
- Containerization
- Configuration and secrets management
- Testing and validation automation
- Deployment automation
- Monitoring and observability
- Infrastructure as code
- Cloud provisioning and orchestration
- Production readiness and security

The skill should clearly say whether the project is in a beginner, intermediate, or growing DevOps stage.

### 3. Check what is already solid

Summarize what the user has already achieved in a way that reflects evidence, for example:

- strong Git workflow discipline
- CI with automated test execution
- working container-based project structure
- basic service and app architecture in place
- repeated validation loops through tests and automation

This section should be honest and specific. It should not overstate maturity if the project still lacks deployment or monitoring fundamentals.

### 4. Check what is still missing or risky

Before recommending the next step, evaluate whether the project is missing foundational DevOps work. Typical missing areas include:

- deployment pipeline to staging or production
- environment separation (dev/staging/prod)
- secrets management
- health checks and readiness probes
- logging and observability
- infrastructure-as-code or cloud provisioning
- rollback strategy
- monitoring/alerting
- release automation
- security scanning and dependency review

If a topic is missing, recommend it even if the user suggested a different idea.

### 5. Evaluate the user’s next idea

If the user says they want to focus on something specific, for example:

- Kubernetes
- Terraform
- Ansible
- monitoring
- cloud deployment
- security

Then do the following:

- acknowledge the idea
- evaluate whether it is relevant and valuable
- check whether the project has the prerequisites for it
- explain why it may or may not be the best next move

Important rule: the user’s interest is a signal, not an automatic override. If the project is still missing a core DevOps foundation, say so clearly.

### 6. Recommend the best next step

The recommendation should be prioritized using this logic:

1. Foundation first: reproducibility, environment stability, automation, security basics
2. Delivery pipeline next: CI/CD, deployment, rollback, release flow
3. Observability and operations next: monitoring, logs, alerts
4. Infrastructure and cloud abstractions next: IaC, orchestration, cloud deployment
5. Advanced specialization last: Kubernetes, service mesh, chaos engineering, advanced security, platform engineering

A strong recommendation should be in this format:

- Current stage: X
- Achievements: Y
- Missing foundations: Z
- User intention: A
- Recommended next move: B
- Why this is the right next step: C

### 7. Produce a balanced recommendation when there is a conflict

If the user says “I want to do Kubernetes next” but the project still lacks deployment automation, environment separation, or sensible observability, respond like this:

- “Your idea is useful, but the project is not yet ready for Kubernetes as the next milestone.”
- “The more important next step is to solidify deployment automation and environment management first.”
- “Kubernetes becomes valuable after the app has a reliable release path and health checks.”

This ensures the system respects the user’s interest without ignoring foundational DevOps learning.

## Decision rules

- Always ground the assessment in actual project evidence.
- Prefer project-specific recommendations over generic DevOps advice.
- Prefer foundational gaps over trendy topics when fundamentals are missing.
- Do not assume the user’s requested topic is the correct next step.
- Use the user’s suggestion as a context signal, not as a command.
- If the project is still immature in a core area, say that explicitly.
- Favor realistic learning sequences over jumping to complex tools too early.

## Example output

User: “I want to learn Kubernetes next.”

Assistant:

- Current stage: Git workflows + CI + containerized app basics
- Achievements: custom Git skill, GitHub Actions pipeline, Docker setup, Django app, tests
- Missing foundations: deployment flow, environment separation, health checks, observability, secrets handling
- User intention: Kubernetes is a valid long-term topic
- Recommendation: focus on deployment automation and production readiness before Kubernetes
- Why: Kubernetes adds complexity without solving the project’s core release and operational gaps

## Suggested progress model for this project

This project shows evidence of early-to-mid DevOps learning progress. In this context, the next realistic milestones are likely:

1. strengthen local and CI validation quality
2. add deployment and environment strategy
3. add health checks and monitoring basics
4. introduce infrastructure as code or cloud deployment
5. then evaluate Kubernetes and orchestration as a later step

## Implementation notes for the agent

Use a concise but evidence-driven review format:

- project evidence summary
- maturity assessment
- missing links
- user intention
- final recommendation

The final answer should feel like a mentor, not a generic chatbot. It should be honest about the project’s current level and direct about what should come next.
