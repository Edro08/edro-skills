---
name: edro-sdlc
description: >-
  Edro's dual-mode engineering skill and multi-role SDLC workflow. Runs in
  Lite Mode (single-agent) for small fixes, onboarding, Git readiness, and
  portability checks, or SDLC Mode (multi-role orchestrator via `/edro-sdlc`)
  for Product -> Design (specs/* mockups) -> Tech Lead/Architect -> Dev -> QA ->
  Security (Max Retries = 2) -> User UAT, while enforcing branch safety,
  `AGENTS.md`/`agents/` context tracking, portability audits, and explicit
  Git commit consent.
---

# Edro SDLC & Dev Standards Workflow

This skill supports **two execution modes**. Pick the lightest mode that fits the task (or follow the user's explicit request):

| Mode | When to Use | How It Executes |
| :--- | :--- | :--- |
| **Lite Mode** *(Single-Agent)* | Small bugfixes, minor refactors, repo onboarding, Git prep, portability audits, or simple tasks not needing PRD/mockups | Execute directly in one agent without spawning subagents: **Step 0** → apply [roles/dev.md](roles/dev.md) → tests + `audit-paths` (**Step 4.4**) → **Step 6** (update `history.md`/`fases.md` if present + Git consent gate). |
| **SDLC Mode** *(Multi-Role)* | New features, product/UI/API design, substantial architecture changes, or explicit full-cycle `/edro-sdlc` requests | Act as the **Orchestrator** coordinating clean role subagents (Option A) via `agents/` handoff contracts from **Step 0 → Step 6**. Never merge `dev` with `qa` or `security`. |

```text
[Lite Mode]:  [0. Git & Onboarding] ─▶ [Dev Standards + Tests] ─▶ [audit-paths] ─▶ [6. History & Git Consent]

[SDLC Mode]:  [0. Git & Onboarding] ─▶ [1. Product (prd.md)] ─▶ [2. Design (specs/*)] ─▶ ✋ GATE 1: User approves mockups
                                                                                                      │
                 ┌────────────────────────────────────────────────────────────────────────────────────┘
                 ▼
              [3. Tech Lead / Architect] ─▶ ✋ GATE 2 (if substantial) ─▶ [4. Dev (implements + reports)]
                                                                             ▲        │
                 ┌───────────────────────────(retry_count <= 2)──────────────┤        ▼
              [Tech Lead → Dev fixes] ◀── FAIL ── [5B. Security] ◀── PASS ── [5A. QA] ◀─ [4.5 Tech Lead Review]
                 ▲                                      │                        │
                 └────────────────── FAIL ──────────────┼────────────────────────┘
                                                        │
                                                       PASS
                                                        ▼
                                            ✋ GATE 3: UAT + History + Explicit Git Commit
```

## Quick Routing (Entry Points)

| Intent / Invocation | Mode & Path |
| :--- | :--- |
| Quick bugfix, minor refactor, onboarding, or Git/portability task | **Lite Mode**: **Step 0** → [roles/dev.md](roles/dev.md) → **Step 4.4** → **Step 6** |
| Close an already-tested task (`audit-paths`, `history.md`, `fases.md`, Git) | **Lite Mode**: **Step 4.4 → Step 6** |
| New feature / product idea / UI, API, or CLI design | **SDLC Mode**: **Step 0 → Step 6** (full pipeline) |
| Architecture or dev implementation with specs already approved | **SDLC Mode**: **Step 0 → Step 3 → Step 6** |
| Independent QA + Security audit loop only | **SDLC Mode**: **Step 5** (`retry_count = 0`) → **Step 6** |

---

## Subagent Setup (Option A)

Define/invoke clean role subagents on demand (`define_subagent` with `EnableWriteTools: true`, `EnableSubagentTools: false` + `invoke_subagent`), passing each subagent **its role file** plus **only the relevant input artifact paths** in `agents/` (or `<Artifact Directory Path>/scratch/agents/` if the user declined repo onboarding in Step 0):

| Subagent Role | Role Prompt | Write Scope Boundary | Primary Output Contract |
| :--- | :--- | :--- | :--- |
| `product` | [roles/product.md](roles/product.md) | Only `agents/specs/prd.md` (no source code) | `agents/specs/prd.md` |
| `design` | [roles/design.md](roles/design.md) | Only `agents/specs/*` (no source code) | `agents/specs/design.md` + `.png`/`.svg`/`.json`/`.html` mockups |
| `tech-lead` | [roles/tech-lead.md](roles/tech-lead.md) | Only `agents/specs/architecture.md` & `agents/context/fases.md` | `agents/specs/architecture.md` + `agents/context/fases.md` |
| `dev` | [roles/dev.md](roles/dev.md) | Full repo + scripts + `agents/context/fases.md` | Code, unit tests, progress reports, `audit-paths` clean |
| `qa` | [roles/qa.md](roles/qa.md) | Only test execution + `agents/context/qa-report.md` (no code edits) | `agents/context/qa-report.md` (`STATUS: PASS \| FAIL`) |
| `security` | [roles/security.md](roles/security.md) | Only scanners + `agents/context/security-report.md` (no code edits) | `agents/context/security-report.md` (`STATUS: PASS \| FAIL`) |

> **Orchestrator & Anti-bias rules**:
> - **Orchestrator owns user communication & invocation**: Subagents return their artifacts and summaries to the Orchestrator; the Orchestrator presents all questions/Gates (`Gate 0`–`Gate 3`) to the user and invokes the next subagent.
> - **Fresh verification contexts**: Always launch `qa` and `security` as **fresh subagents** so they verify against `prd.md`, `design.md`, `architecture.md`, and real execution—never inheriting `dev`'s assumptions.

---

## Step 0: Git Preflight & Project Onboarding (`Gate 0`)

1. **Branch Safety Preflight**:
   - Run `git rev-parse --is-inside-work-tree`, `git branch --show-current`, and `git status --short`.
   - **HARD GATE**: If on `main` or `master` and files will be modified, **STOP** and ask the user to create/switch to a dedicated branch (or follow the active Git skill such as `edro-git`).
2. **Context Onboarding** ([ref/agents.md](ref/agents.md)):
   - Check for root `AGENTS.md` and `agents/` (`specs/`, `context/`).
   - If missing, **STOP** and ask verbatim:
     > *"He notado que este proyecto aún no cuenta con `AGENTS.md` ni la estructura de contexto en `agents/`. ¿Deseas que los configure ahora para llevar el registro de fases, historial de cambios y arquitectura?"*
   - If approved, scaffold base templates from [`resources/`](resources/).
   - If declined, do **not** create `AGENTS.md` or `agents/` in the repository; instead, route all role handoff files (`specs/*` and `context/*` reports) under `<Artifact Directory Path>/scratch/agents/` for the duration of the session.
   - If already present, read `AGENTS.md` and current `agents/context/fases.md` / top of `agents/context/history.md`.

---

## Step 1: Product Definition (`product`)

1. Invoke the `product` subagent to analyze the user request and identify ambiguities.
2. If `product` surfaces open questions, the Orchestrator presents them concisely to the user and passes the answers back to `product` before finalizing scope.
3. Produce `agents/specs/prd.md` with clear **In Scope**, **Out of Scope**, and testable **Acceptance Criteria**.

---

## Step 2: Design & Mockups (`design` + `Gate 1`)

1. Invoke the `design` subagent with `agents/specs/prd.md`.
2. Store all design deliverables inside `agents/specs/` (`.png`, `.svg`, endpoint `.json`, HTML mockups, or CLI samples) and summarize them in `agents/specs/design.md`.
3. **HARD GATE 1 (User Design Sign-off)**:
   - The Orchestrator presents the base design and mockups to the user.
   - Debate improvements and iterate with `design` (and `product` if scope shifts) until the user explicitly approves the concrete target.

---

## Step 3: Architecture & Phase Planning (`tech-lead` + `Gate 2`)

1. Invoke the merged `tech-lead` subagent (Tech Lead + Architect) with `prd.md` and `design.md`.
2. Update `agents/specs/architecture.md` and break work into phases in `agents/context/fases.md`.
3. **GATE 2**: For substantial features or architectural shifts, the Orchestrator presents the architecture and phase plan to the user for quick alignment before coding.

---

## Step 4: Development & Change Handling (`dev`)

1. The Orchestrator passes `tech-lead`'s active phase tasks to the `dev` subagent (enforcing all base rules in [roles/dev.md](roles/dev.md)).
2. `dev` implements clean, idiomatic code + unit tests, updates `agents/context/fases.md` (when repo onboarding is enabled), and returns a progress report to the Orchestrator (to keep **Tech Lead**, **Product**, and the **User** aligned).
3. **Change Request Protocol** (when requirements, design contracts, or phases change mid-development):
   - **Minor adjustment** *(preserves existing UX, API/CLI contracts, and architecture)*: `tech-lead` approves and `dev` applies it directly in Step 4.
   - **Contract-changing adjustment** *(alters scope, UI/API/CLI behavior, architecture, or phase breakdown)*: **pause** affected implementation and sync only the impacted specs before continuing:
     - Scope change → `product` updates `prd.md`.
     - UI/Endpoint/CLI change → `design` updates `design.md` / `specs/*` (+ quick user sign-off at `Gate 1`).
     - Architecture or phase shift → `tech-lead` updates `architecture.md` and re-plans `fases.md`.
4. **Portability & Unit Test Gate**: `dev` must verify unit tests pass and run the portability scanner from the repo root with `exit 0` ([ref/portability.md](ref/portability.md)):
   - Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/audit-paths.ps1" -Root .`
   - POSIX: `bash "<path-to-skill>/scripts/audit-paths.sh" .`

---

## Step 4.5: Phase & Diff Review (`tech-lead`, Pre-QA Gate)

Before launching fresh **QA**, the Orchestrator invokes `tech-lead` to review `dev`'s diff and phase state:
1. **Architecture & Code Quality**: Confirm implementation matches `architecture.md`, stays clean/idiomatic, and respects module boundaries.
2. **Phase Sync**: Confirm `agents/context/fases.md` accurately reflects completed vs remaining phases.
3. **Spec Drift Check**: Confirm code does not contradict `prd.md` or `design.md`; if any discrepancy exists, either have `dev` align the code or update the specs (`product`/`design`/`tech-lead`) so **QA** validates against accurate contracts.

---

## Step 5: QA & Security Verification Loop (`Max Retries = 2`)

Initialize `retry_count = 0`. Both **5A (QA)** and **5B (Security)** share this remediation budget (`retry_count <= 2`).

1. **5A. QA Verification (`qa`, fresh subagent)**:
   - Run real integration and end-to-end checks against `prd.md` and `design.md`; write `agents/context/qa-report.md`.
   - If `STATUS: PASS`: proceed to **5B (Security)**.
   - If `STATUS: FAIL`:
     - Increment `retry_count`.
     - **HARD ESCALATION GATE**: If `retry_count > 2`, **STOP the autonomous loop** and escalate to the user with `qa-report.md` so architectural or manual decisions can be made.
     - Otherwise (`retry_count <= 2`): Orchestrator invokes `tech-lead` to triage defects → invokes `dev` to apply fixes → re-run **5A (QA)** (fresh subagent).
2. **5B. Security Audit (`security`, fresh subagent)**:
   - Only enters after **QA** reports `STATUS: PASS`.
   - Run automated vulnerability/hardening/portability checks and manual security review against `prd.md`, `design.md`, and `architecture.md`; write `agents/context/security-report.md`.
   - If `STATUS: PASS`: proceed to **Step 6**.
   - If `STATUS: FAIL`:
     - Increment `retry_count`.
     - **HARD ESCALATION GATE**: If `retry_count > 2`, **STOP the autonomous loop** and escalate to the user with `security-report.md` and `qa-report.md` so architectural or manual decisions can be made.
     - Otherwise (`retry_count <= 2`): Orchestrator invokes `tech-lead` to triage security findings → invokes `dev` to apply fixes → re-run **5A (QA)** → re-run **5B (Security)**.

---

## Step 6: UAT Delivery, Context Closure & Git Consent (`Final Gate`)

1. **Context Retention** (when `agents/context/` exists):
   - Prepend the completed milestone to `agents/context/history.md` (reverse chronological order, relative links, verified commands).
   - Mark completed phases `🟢` in `agents/context/fases.md`.
2. **Final Portability Check**: Confirm `audit-paths` exits with `0` after final doc/context edits.
3. **User UAT & Git Handoff (`HARD STOP`)**:
   - Present the finished work for user review/UAT, including unit test + `audit-paths` results (and summaries of `qa-report.md` `PASS` and `security-report.md` `PASS` when running in **SDLC Mode**).
   - Run `git branch --show-current` and `git status --short` to summarize the ready working tree.
   - **NEVER** run `git commit` or `git push` autonomously; stop here and defer commit formatting and execution to the active Git skill (e.g., `edro-git`) or the user's explicit instructions.

---

## Quick Reference & Assets

| Area | Resource | Purpose |
| :--- | :--- | :--- |
| **Role Prompts** | [`roles/`](roles/) | `product.md`, `design.md`, `tech-lead.md`, `dev.md`, `qa.md`, `security.md` |
| **Context Protocol** | [ref/agents.md](ref/agents.md) | Onboarding gate, artifact contracts, `history.md` formatting |
| **Portability Rules** | [ref/portability.md](ref/portability.md) | Path-agnostic rules and audit remediation |
| **Templates** | [`resources/`](resources/) | `AGENTS.template.md`, `prd.md`, `design.md`, `architecture.md`, `history.md`, `fases.md`, `qa-report.md`, `security-report.md` |
| **Audit Scripts** | [scripts/audit-paths.ps1](scripts/audit-paths.ps1), [scripts/audit-paths.sh](scripts/audit-paths.sh) | Automated host-path scanners |
