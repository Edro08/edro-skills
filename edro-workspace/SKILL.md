---
name: edro-workspace
description: >-
  Fast, low-token workspace inspection utilities. Use when the user asks what
  services, projects, or technology stacks exist in a workspace or directory
  (e.g., "what type are the services?", "de qué tipo son los svc?").
---

# Edro Workspace Utilities

Use this skill to inspect multi-project workspaces quickly without manually scanning directories and manifest files.

## Detecting Service Stacks

When the user asks what technology, language, or framework each service/folder in the workspace uses:

1. Run the bundled PowerShell script directly against the target workspace root (by default it writes a Markdown table to `services-report.md` and prints a single summary line to keep token usage minimal):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-this-skill>/scripts/detect-services.ps1" -Path "."
   ```
   - Pass `-OutFile <path.md>` to customize the Markdown report path (default: `services-report.md`).
   - Pass `-Console` to print `<folder> - <stack>` lines directly to stdout instead of writing a `.md` file.
   - Pass `-Depth 2` if services are grouped inside subdirectories (e.g., `services/svc-1`, `apps/web`).
2. Share the generated report path and summary with the user.
3. **Only** inspect a directory manually if the script reports `Unknown` and the user needs more detail on that specific folder.

> For multi-repo `git fetch` or branch inventory (`main`/`master`, `sprint/*`, `release/*`, `feat/*`), use the `edro-git` skill (`scripts/fetch-branches.ps1`).
