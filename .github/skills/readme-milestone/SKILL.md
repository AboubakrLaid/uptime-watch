---
name: readme-milestone
description: "Use when: the user wants to add a new milestone under '## What I have built so far' in the README, based on recent work, project progress, or a meaningful delivery milestone. The skill reads the current README and recent repo changes, proposes validated milestone titles and notes, and only edits the README after the user confirms the wording."
---

# README Milestone Writer

Use this skill when the user wants to add a new milestone to the repository README in a concise, credible, recruiter-friendly style.

## Goal

Add a new milestone under the section "## What I have built so far" with:

- a simple, business-like title
- a date
- a repo snapshot trace link
- bullet points that explain what changed, why it mattered, and what the outcome was
- direct, professional wording that sounds like a real engineer speaking plainly

The README is meant to be readable by recruiters and technical peers, so the tone should be clear, confident, and evidence-based.

## Required workflow

### 1. Read the README first

Before writing anything:

- read the current README thoroughly enough to understand the existing milestones and tone
- read the section "## What I have built so far"
- follow the same formatting and language style already used in the file
- do not rewrite previous milestones unless the user explicitly asks

### 2. Review recent work

Before proposing a milestone title or notes:

- inspect recent git changes and recent commit history
- review the files changed in the latest work
- identify the real learning or delivery outcome from those changes
- use the commit and diff as the source of truth, not guesswork

If the user gives text and says something like "USE IT", treat that as explicit intent and prioritize the wording they provided.

### 3. Propose the milestone before editing

Before editing the README, present:

- 2 to 3 title options
- a short explanation of why each option fits the current work
- the key bullet points that would accompany the selected option

Ask the user to validate the title and notes before making the change.

Do not insert the milestone into the README until the user confirms the wording.

### 4. Keep the language simple and credible

Use direct, concrete language.

Prefer:

- added
- configured
- implemented
- validated
- deployed
- secured
- simplified
- exposed
- tested

Avoid:

- vague phrases like "improved the workflow"
- buzzwords without substance
- marketing language
- filler sentences that do not communicate a real engineering outcome

### 5. Write milestone content in the repo's format

Each milestone should look like this:

### X. <Simple milestone title> — YYYY-MM-DD

- Trace: [snapshot at <hash>](https://github.com/<owner>/<repo>/tree/<hash>)
- <important engineering fact>
- <why it mattered>
- <what changed>
- <what the result was>

The title should be:

- simple
- right to the point
- easy for a recruiter to understand
- specific enough to reflect actual work

### 6. Keep bullets useful for recruiters and recall

Each bullet should capture real value.

Include what matters most:

- what was built or configured
- why it matters in production or delivery
- what problem it solved
- what operational or engineering capability improved
- what a recruiter or reviewer should notice

The bullets should make it easy to remember the work later.

### 7. Add the trace for credibility

Every milestone must include a repo snapshot link and date.

Use the format:

- Trace: [snapshot at 4c0cb6d](https://github.com/AboubakrLaid/uptime-watch/tree/4c0cb6d)

This gives a clear, trustworthy point in time for the work and makes the README auditable.

## Writing rules

- Keep each milestone short and readable.
- Use simple sentences.
- Speak like a real engineer, not a marketing copywriter.
- Focus on outcomes and engineering decisions.
- Be precise about the technical work.
- Mention the practical result, not just the task.
- If something is incomplete, say so directly.

## Safety rules

- Never edit the README before the user validates the title and notes.
- Do not rewrite older milestones unless the user asks for it.
- Respect explicit user intent, including phrases like "USE IT".
- Use repository evidence and recent work as the basis for content.
- Keep the milestone list chronological and consistent.
- Prefer facts over hype.

## Example milestone pattern

### 6. Docker environment separation — 2026-11-01

- Trace: [snapshot at cff9225](https://github.com/AboubakrLaid/uptime-watch/tree/cff9225)
- Split the Docker setup into separate development and production configurations.
- Kept the production stack aligned with a real deployment layout.
- Reinforced the distinction between local workflow and production-facing setup.
- This makes the project easier to run safely in different environments.

## Implementation notes for the agent

When the user asks to add a milestone:

1. read the README
2. review recent git changes
3. propose 2–3 milestone title options with supporting notes
4. ask the user to choose
5. only after confirmation, insert the milestone into the README
6. keep the language concise, credible, and recruiter-friendly

This keeps the workflow steady, transparent, and credible.
