---
name: push-new-feature
description: "Use when: pushing a new feature, creating a feature branch, reviewing modified files, choosing a commit message, or publishing a branch to origin. Helps inspect git changes, infer the task, suggest commit titles, create a feature branch from main when needed, stage the files, commit them, and push the branch."
---

# Push New Feature

Use this skill when the user wants to prepare and publish a feature change without manually repeating the branch/commit/push flow.

## Goal

Take the current working tree, understand the task from the modified files, propose a small set of commit message options, confirm one, then:

1. create or switch to the correct feature branch if needed
2. stage the relevant files
3. create a commit
4. push the branch to origin

If the current branch is main, do not push directly. Suggest a feature branch name first, confirm it, and create the branch before committing and pushing.

## Required workflow

### 1. Check repository status

Inspect the working tree before making any change.

- run git status --short
- review changed files
- identify whether the work is a feature, bugfix, refactor, chore, or docs change
- ignore unrelated noise or generated files unless the user explicitly wants them included

### 2. Understand the task from the diff

Read the modified files and relevant surrounding context to infer what changed.

- use git diff --stat or git diff for a quick summary
- read the exact modified files only when necessary
- summarize the feature in plain language
- determine whether the patch is a single feature or several smaller changes

### 3. Propose commit messages

Before committing, propose 3–5 concise options matching the project’s conventions.

Prefer conventional commit styles, for example:

- feat: add X
- fix: resolve Y
- chore: add project tooling
- refactor: simplify Z
- docs: update setup instructions
- test: cover new feature behavior

Then ask the user to choose one.

### 4. Decide branch strategy

Check the current branch.

- If the branch is main, do not push directly. Suggest 2–5 branch names based on the task and ask the user to confirm one.
- If the branch is not main, ask the user whether they want to push to the current branch or switch to another branch.
- If the user wants to keep the current branch, continue using it and confirm that is the correct target.
- If the user wants another branch, suggest 2–5 feature branch names and ask for confirmation.
- If the user asks for a new branch name that is not already present, create it.
- If the chosen branch already exists, switch to it and continue.
- Examples:
  - feat/add-website-monitoring
  - feat/uptime-dashboard
  - chore/precommit-setup
  - fix/resolve-user-creation-bug

### 5. Stage and commit

Once the commit message is confirmed:

- if the user names specific files, stage only those files
- if the user does not name specific files, stage all modified files in the working tree
- if there are unrelated changes, ask before including them
- create a commit with a clear message
- do not stage or commit files that were not explicitly approved unless the user said to include everything

### 6. Push the branch

Push the branch to origin.

- if the branch is new, use git push -u origin <branch-name>
- if the branch already exists and is tracking remote, use git push

### 7. Final response

After a successful push, report:

- current branch name
- remote branch name
- commit hash
- whether the branch was created from main or reused
- the chosen commit message

## Safety rules

- Never commit or push without user confirmation of the commit message.
- Never push directly from main without creating or switching to a feature branch.
- If the current branch is not main, ask whether to continue on it or choose another branch before pushing.
- If the user specifies files, stage only those files.
- If the user does not specify files, stage all modified files.
- Do not include unrelated modifications unless the user asks for them.
- Prefer small, clear, conventional commit messages.
- If the task is ambiguous, ask one clarification question before committing.

## Example interaction

User: “Push this new feature.”

Assistant:

1. runs git status --short
2. reads the modified files and summarizes the task
3. proposes:
   - feat: add website uptime tracking
   - chore: add monitoring setup
   - fix: resolve website status flow
4. asks the user to choose one
5. after confirmation, checks branch status
6. if on main, suggests names like feat/add-uptime-tracking and asks for confirmation
7. if on a non-main branch, asks: “Do you want to push to the current branch or create/switch to another feature branch?”
8. creates or switches to the chosen branch, stages the files, commits, and pushes
9. reports the result

## Implementation notes for the agent

Use a short, guided workflow and ask for confirmation at the decision points:

- commit message choice
- branch name choice when main is active
- staging scope: specific files vs all modified files
- whether unrelated files should be excluded

This preserves safety while keeping the flow fast and repetitive.
