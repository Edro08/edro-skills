---
name: edro-git
description: >-
  Edro's Git workflow conventions, dedicated working branch rules,
  branch-prefixed commit message formatting (`<branch>: <description>`),
  mandatory explicit user confirmation before committing or pushing, and
  multi-repo fetch/branch inventory utilities. Use when creating branches,
  staging changes, drafting commit messages, executing Git commit/push
  operations, or fetching/listing branches across one or more services.
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

- **No Co-Authors**: Agents are **STRICTLY PROHIBITED** from adding `Co-authored-by:` trailers or any co-author attribution to commit messages.

### Examples by Branch Type

- **Task branch (`TASK-...`)**:
  - Branch: `TASK-001`
  - Commit: `"TASK-001 implement health checks for database"`
- **Feature branch (`feat/...`)**:
  - Branch: `feat/integrate-go-utils`
  - Commit: `"feat/integrate-go-utils add git convention skill and register in agent instructions"`
- **Bugfix branch (`fix/...`)**:
  - Branch: `fix/read-timeout`
  - Commit: `"fix/read-timeout adjust server timeout to prevent early disconnect"`

---

## 3. Explicit User Confirmation (Golden Rule)

1. **Never commit or push automatically**:
   - Agents must **NEVER** run `git commit` or `git push` autonomously or as part of an automated chain.
2. **Prepare the working tree**:
   - Inspect `git branch --show-current` and `git status --short`, stage/verify changes as needed, and present the proposed commit message.
3. **Wait for explicit user instruction**:
   - Only run `git commit` (and `git push` if requested) when the user explicitly instructs it (e.g., *"commit"*, *"haz el commit"*, *"commit and push"*).

---

## 4. Multi-Repo Fetch & Branch Inventory

When the user asks to `git fetch` across multiple services/repositories or wants an overview of their `main`/`master`, intermediate (`sprint/*`, `release/*`, `develop`, `staging`), task (`feat/*`, `fix/*`, `bug/*`, `task/*`), and current branches:

- Run the bundled PowerShell script instead of issuing per-repo commands (by default it writes a Markdown table to `branches-report.md` and prints a single summary line to keep token usage minimal):
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-this-skill>/scripts/fetch-branches.ps1" -Path "."
  ```
- Optional flags:
  - `-OutFile <path.md>` to customize the Markdown report path (default: `branches-report.md`).
  - `-Services svc-1,svc-2` to target specific service folders.
  - `-NoFetch` to inspect cached branches without fetching from remotes.
  - `-Console` to print the summary directly to stdout instead of writing a `.md` file.
  - `-Depth 2` if repositories are nested in subdirectories.

### Bulk Branch Switch

To switch branches across multiple repositories safely (e.g., after editing the `Current` column in `branches-report.md`, or moving services to `main`/`master` or a shared sprint branch):

- Run the bundled switch script (always prefer `-DryRun` first when switching many repos):
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-this-skill>/scripts/switch-branches.ps1" -Path "." -ReportFile "branches-report.md" -DryRun
  ```
- Modes & flags:
  - Default (report-driven): reads target branches from the `Current` column of `-ReportFile` (`branches-report.md`).
  - `-TargetMain`: switches matching repositories to their `main` or `master` branch.
  - `-Branch <name>`: switches matching repositories to a specific branch.
  - `-Services svc-1,svc-2`: filter target service folders.
  - `-Pull`: run `git pull --ff-only` after switching.
  - `-Stash`: stash uncommitted changes instead of skipping dirty repos (by default dirty repos are skipped).
  - `-OutFile <path.md>` / `-Console`: customize report output (default: `switch-report.md`).
