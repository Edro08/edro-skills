---
name: edro-git
description: >-
  Edro's Git workflow conventions, dedicated working branch rules,
  branch-prefixed commit message formatting (`<branch>: <description>`), and
  mandatory explicit user confirmation before committing or pushing. Use when
  creating branches, staging changes, drafting commit messages, or executing
  Git commit/push operations.
---

# Edro Git Workflow & Commit Conventions

Use this skill when managing branches, preparing changes, drafting commit messages, and performing Git operations across any repository.

---

## 1. Branching Workflow (Preflight Gate)

- **Active branch check**: Always inspect the active branch before making changes:
  ```bash
  git branch --show-current
  ```
- **Protected branches**: Never develop or commit directly on `main` or `master` (except when the user explicitly overrides, e.g., initial bootstrap commit).
- **Dedicated working branches**: Work must occur on a dedicated branch (`feat/<slug>`, `fix/<slug>`, `TASK-<id>`, `chore/<slug>`).
- **Gate behavior**: If the repository is currently on `main` or `master`, pause and ask the user whether to create/switch to a dedicated branch before editing code.

---

## 2. Mandatory Commit Message Format

Unless the repository explicitly defines another standard (such as Conventional Commits in a team repo), every commit message **MUST** start with the exact name of the active branch, followed by `: ` and a concise description written in the imperative or present tense:

```text
"<branch-name>: <change description>"
```

### Examples by Branch Type

- **Task branch (`TASK-...`)**:
  - Branch: `TASK-001`
  - Commit: `"TASK-001: implement health checks for database"`
- **Feature branch (`feat/...`)**:
  - Branch: `feat/integrate-go-utils`
  - Commit: `"feat/integrate-go-utils: add git convention skill and register in agent instructions"`
- **Bugfix branch (`fix/...`)**:
  - Branch: `fix/read-timeout`
  - Commit: `"fix/read-timeout: adjust server timeout to prevent early disconnect"`

---

## 3. Explicit User Confirmation (Golden Rule)

1. **Never commit or push automatically**:
   - Agents must **NEVER** run `git commit` or `git push` autonomously or as part of an automated chain.
2. **Prepare the working tree**:
   - Inspect `git branch --show-current` and `git status --short`, stage/verify changes as needed, and present the proposed commit message.
3. **Wait for explicit user instruction**:
   - Only run `git commit` (and `git push` if requested) when the user explicitly instructs it (e.g., *"commit"*, *"haz el commit"*, *"commit and push"*).
