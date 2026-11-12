---
name: edro-sdlc
description: >-
  Edro's dual-mode engineering skill and multi-role SDLC workflow. Runs in
  Lite Mode (mandatory Step 0 router -> jump to Step 4 Dev + mandatory Gate 3,
  Step 5 Code Review, Step 6 QA, or Step 7 Security) or SDLC Mode (multi-role
  orchestrator via `/edro-sdlc`: Step 0 Onboarding -> Step 1 Product -> Step 2
  Design + Gate 1 -> Step 3 Tech Lead + Gate 2 -> Step 4 Dev -> Step 5 Code
  Review + Gate 3 Consultant -> Step 6 QA -> Step 7 Opt-in Security -> Step 8
  UAT & Git Consent), enforcing branch safety, `AGENTS.md`/`agents/` context
  tracking, portability audits, and explicit Git commit consent.
---

# Edro SDLC & Dev Standards Workflow

This skill supports **two execution modes**. Pick the lightest mode that fits the task (or follow the user's explicit request):

| Mode | When to Use | How It Executes |
| :--- | :--- | :--- |
| **Lite Mode** *(Modular Router)* | Small bugfixes, minor refactors, standalone code reviews, targeted QA/Security runs, repo onboarding, or tasks not needing PRD/mockups | **Step 0 (`Gate 0`) is always mandatory**. From Step 0, jump to the requested step (**`Step 4` Dev**, **`Step 5` Code Review**, **`Step 6` QA**, or **`Step 7` Security**). Whenever **`Step 4` (Dev)** runs, **`Gate 3` (Tech Lead Consultant)** is mandatory before closing or triggering Steps `5`/`6`/`7` on demand, finishing at **`Step 8`**. |
| **SDLC Mode** *(Multi-Role)* | New features, product/UI/API/CLI design, substantial architecture changes, or explicit full-cycle `/edro-sdlc` requests | Act as the **Orchestrator** coordinating clean role subagents (Option A) via `agents/` handoff contracts from **`Step 0` → `Step 8`**. Never merge `dev` with `qa` or `security`. |

```text
[Lite Mode]:  [0. Git & Onboarding (Mandatory)]
                 ├──▶ [4. Dev + Tests + audit-paths] ─▶ ✋ GATE 3 (Tech Lead Consultant — Mandatory):
                 │       ├── Request changes to Dev (N rounds, logged in code-review.md) ──▶ [4. Dev]
                 │       ├── Trigger on demand ──▶ [5. Full Review] / [6. QA] / [7. Security] ──▶ [8. Closure & Git]
                 │       └── Approve ("todo bien") ──▶ consolidate architecture.md + fases.md ──▶ [8. Closure & Git]
                 ├──▶ [5. Code Review direct (hand-written code review)] ──▶ ✋ GATE 3 ──▶ [8. Closure & Git]
                 ├──▶ [6. QA direct] ──▶ ✋ GATE 4 (Opt-in Security?) ──▶ [8. Closure & Git]
                 └──▶ [7. Security direct] ──▶ [8. Closure & Git]

[SDLC Mode]:  [0. Git & Onboarding] ─▶ [1. Product (prd.md)] ─▶ [2. Design (specs/*)] ─▶ ✋ GATE 1: User approves mockups
                                                                                                      │
                 ┌────────────────────────────────────────────────────────────────────────────────────┘
                 ▼
              [3. Tech Lead / Architect] ─▶ ✋ GATE 2 (if substantial) ─▶ [4. Dev (implements + tests + audit-paths)]
                                                                                                      │
                 ┌────────────────────────────────────────────────────────────────────────────────────┘
                 ▼
              [5. Code & Architecture Review (code-review.md)]
                 ├─ 5.1 Autonomous loop: tech-lead ⇄ dev (review_retry_count <= 2; escalates to Gate 3 if > 2)
                 └─ 5.2 ✋ GATE 3 (Tech Lead Consultant — N rounds; each request resets review_retry_count = 0)
                        └─ On "todo bien": tech-lead marks PASS & consolidates into architecture.md + fases.md
                 │
                 ▼
              [6. QA Verification (qa-report.md, qa_retry_count <= 2)]
                 ├─ FAIL (<= 2) ──▶ [tech-lead triage → dev fix → 6. QA]
                 └─ PASS
                     │
                     ▼
              ✋ GATE 4 (Security Opt-in): Ask user whether to run Step 7 (Security) or skip to Step 8
                 ├─ Run Security ──▶ [7. Security Audit (security-report.md, security_retry_count <= 2)]
                 │                      ├─ FAIL (<= 2) ──▶ [tech-lead → dev fix → 6. QA → 7. Security]
                 │                      └─ PASS ──▶ [8. UAT & Git Consent]
                 └─ Skip Security ─────────────────▶ [8. UAT & Git Consent]
                                                        │
                                                        ▼
                                            ✋ GATE 5 (Final): UAT + History + Explicit Git Commit
```

## Quick Routing (Entry Points)

| Intent / Invocation | Mode & Path |
| :--- | :--- |
| Quick bugfix, minor refactor, or small feature not needing PRD/mockups | **Lite Mode**: **Step 0** → **Step 4** ([roles/dev.md](roles/dev.md) + `Step 4.4`) → **`Gate 3`** (request changes, trigger `5`/`6`/`7`, or approve) → **Step 8** |
| Review hand-written or uncommitted code (`Code Review` only) | **Lite Mode**: **Step 0** → **Step 5** (`tech-lead` writes `code-review.md` + **`Gate 3`**) → **Step 8** |
| Test / verify existing features or changes (`QA` only) | **Lite Mode**: **Step 0** → **Step 6** (`qa` writes `qa-report.md`) → **`Gate 4`** (Opt-in Security) → **Step 8** |
| Audit vulnerabilities, hardening, or portability (`Security` only) | **Lite Mode**: **Step 0** → **Step 7** (`security` writes `security-report.md`) → **Step 8** |
| Close an already-reviewed task (`audit-paths`, `history.md`, `fases.md`, Git) | **Lite Mode**: **Step 4.4 → Step 8** |
| New feature / product idea / UI, API, or CLI design | **SDLC Mode**: **Step 0 → Step 8** (full pipeline) |
| Architecture or dev implementation with specs already approved | **SDLC Mode**: **Step 0 → Step 3 → Step 8** |

---

## Subagent Setup (Option A)

Define/invoke clean role subagents on demand (`define_subagent` with `EnableWriteTools: true`, `EnableSubagentTools: false` + `invoke_subagent`), passing each subagent **its role file** plus **only the relevant input artifact paths** in `agents/` (or `<Artifact Directory Path>/scratch/agents/` if the user declined repo onboarding in Step 0):

| Subagent Role | Role Prompt | Write Scope Boundary | Primary Output Contract |
| :--- | :--- | :--- | :--- |
| `product` | [roles/product.md](roles/product.md) | Only `agents/specs/prd.md` (no source code) | `agents/specs/prd.md` |
| `design` | [roles/design.md](roles/design.md) | Only `agents/specs/*` (no source code) | `agents/specs/design.md` + `.png`/`.svg`/`.json`/`.html` mockups |
| `tech-lead` | [roles/tech-lead.md](roles/tech-lead.md) | Only `agents/specs/architecture.md`, `agents/context/fases.md`, & `agents/context/code-review.md` | `architecture.md`, `fases.md`, & `code-review.md` (`STATUS: PASS \| FAIL`) |
| `dev` | [roles/dev.md](roles/dev.md) | Full repo + scripts + `agents/context/fases.md` | Code, unit tests, progress reports, `audit-paths` clean |
| `qa` | [roles/qa.md](roles/qa.md) | Only test execution + `agents/context/qa-report.md` (no code edits) | `agents/context/qa-report.md` (`STATUS: PASS \| FAIL`) |
| `security` | [roles/security.md](roles/security.md) | Only scanners + `agents/context/security-report.md` (no code edits) | `agents/context/security-report.md` (`STATUS: PASS \| FAIL`) |

> **Orchestrator & Anti-bias rules**:
> - **Orchestrator owns user communication & invocation**: Subagents return their artifacts and summaries to the Orchestrator; the Orchestrator presents all questions/Gates (`Gate 0`–`Gate 5`) to the user and invokes the next subagent.
> - **Fresh verification contexts**: Always launch `qa` and `security` as **fresh subagents** so they verify against `prd.md`, `design.md`, `architecture.md`, and real execution—never inheriting `dev`'s assumptions.

---

## Step 0: Git Preflight & Project Onboarding (`Gate 0` — Mandatory in Both Modes)

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
3. **Lite Mode Step Selection (when running in Lite Mode)**:
   - Route directly to the target step requested by the user (**`Step 4` Dev**, **`Step 5` Code Review**, **`Step 6` QA**, or **`Step 7` Security**). If ambiguous, ask which step to run.

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

1. **Implementation**:
   - In **SDLC Mode**, the Orchestrator passes `tech-lead`'s active phase tasks to the `dev` subagent (enforcing all base rules in [roles/dev.md](roles/dev.md)).
   - In **Lite Mode**, the active agent executes [roles/dev.md](roles/dev.md) directly.
2. `dev` implements clean, idiomatic code + unit tests, updates `agents/context/fases.md` (when repo onboarding is enabled), and returns a progress report.
3. **Change Request Protocol** (when requirements, design contracts, or phases change mid-development):
   - **Minor adjustment** *(preserves existing UX, API/CLI contracts, and architecture)*: `tech-lead` approves and `dev` applies it directly in Step 4.
   - **Contract-changing adjustment** *(alters scope, UI/API/CLI behavior, architecture, or phase breakdown)*: **pause** affected implementation and sync only the impacted specs before continuing:
     - Scope change → `product` updates `prd.md`.
     - UI/Endpoint/CLI change → `design` updates `design.md` / `specs/*` (+ quick user sign-off at `Gate 1`).
     - Architecture or phase shift → `tech-lead` updates `architecture.md` and re-plans `fases.md`.
4. **Portability & Unit Test Gate (`Step 4.4`)**: `dev` must verify unit tests pass and run the portability scanner from the repo root with `exit 0` ([ref/portability.md](ref/portability.md)):
   - Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/audit-paths.ps1" -Root .`
   - POSIX: `bash "<path-to-skill>/scripts/audit-paths.sh" .`
5. **Transition from Step 4**:
   - In **SDLC Mode**: proceed to **Step 5** (`5.1` autonomous `tech-lead` review → `5.2 Gate 3`).
   - In **Lite Mode**: proceed directly to **`Gate 3` (`Step 5.2`)**, presenting the technical summary to the user (who may request changes, trigger full `Step 5` / `Step 6` / `Step 7` on demand, or approve to jump to **Step 8**).

---

## Step 5: Code & Architecture Review (`tech-lead` + `Gate 3: Tech Lead Consultant`)

Initialize `review_retry_count = 0`. Working notes, review findings, and consultant iterations are tracked in `agents/context/code-review.md` ([resources/code-review.md](resources/code-review.md)).

1. **5.1 Autonomous Review Loop (`tech-lead ⇄ dev`, `review_retry_count <= 2`)**:
   - The Orchestrator invokes `tech-lead` to review `dev`'s diff against `architecture.md`, `prd.md`, `design.md`, `fases.md` (when present), and stack standards (e.g., `edro-dev-*`), recording findings in `agents/context/code-review.md`.
   - If issues are found:
     - Increment `review_retry_count`.
     - If `review_retry_count <= 2`: `tech-lead` returns concrete fix instructions → `dev` applies fixes and re-runs `Step 4.4` → `tech-lead` re-reviews.
     - If `review_retry_count > 2` (autonomous retries exhausted): **STOP** the autonomous loop and immediately enter **`Gate 3`**, explaining to the human **Tech Lead Consultant** what happened and where `dev`/`tech-lead` got stuck so the user can guide the solution.
2. **5.2 ✋ HARD GATE 3: Tech Lead Consultant Review (`N` Human Iterations)**:
   - Here the user participates as **Tech Lead Consultant / Senior Dev** (inspecting code structure, patterns, boundaries, or behavior before QA runs).
   - The Orchestrator presents a concise technical review summary (and any unresolved escalation from `5.1`).
   - **Consultant Iteration Protocol (`N` rounds allowed)**:
     - Whenever the user requests code adjustments, fixes, or refactors at `Gate 3`:
       1. **Reset `review_retry_count = 0`**.
       2. `tech-lead` documents the requested changes in `agents/context/code-review.md`.
       3. `dev` implements the requested changes and verifies unit tests + `audit-paths` (`Step 4.4`).
       4. `tech-lead` verifies the changes (with up to `2` autonomous retries) and returns to **`Gate 3`**.
   - **On-Demand Step Triggers from `Gate 3` (Lite Mode)**:
     - From `Gate 3`, the user can also request running full **Step 5** (`5.1`), **Step 6 (QA)**, or **Step 7 (Security)** before closing.
3. **5.3 Consolidation on `Gate 3` Sign-off (*"todo bien"*)**:
   - Once the user explicitly approves at `Gate 3`:
     - `tech-lead` marks `STATUS: PASS` in `agents/context/code-review.md` and **integrates/consolidates all final changes into `agents/specs/architecture.md` and `agents/context/fases.md`**.
     - If any consultant-requested change altered external UX/CLI/API contracts or scope, sync `design.md` / `prd.md` so **Step 6 (QA)** validates against accurate specs.
   - Proceed to **Step 6 (QA Verification)** in SDLC Mode (or to **Step 8** in Lite Mode unless the user requested Step 6/7).

---

## Step 6: QA Verification (`qa`, `Max Retries = 2`)

Initialize `qa_retry_count = 0`.

1. **Execute Fresh QA (`qa` subagent)**:
   - Run real integration and end-to-end checks against `prd.md` and `design.md` (or against codebase contracts and user test goals in Lite Mode); write `agents/context/qa-report.md`.
2. **Evaluate Verdict**:
   - If `STATUS: PASS`: proceed to **Step 7 (`Gate 4`: Security Opt-in)**.
   - If `STATUS: FAIL`:
     - Increment `qa_retry_count`.
     - **HARD ESCALATION GATE**: If `qa_retry_count > 2`, **STOP the autonomous loop** and escalate to the user with `qa-report.md` for guidance. (If the user provides direction, reset `qa_retry_count = 0` and resume).
     - Otherwise (`qa_retry_count <= 2`): Orchestrator invokes `tech-lead` to triage defects → invokes `dev` to apply fixes → re-run **Step 6 (`qa`, fresh subagent)**.

---

## Step 7: Security Audit (`Gate 4 Opt-in` + `security`, `Max Retries = 2`)

1. **✋ GATE 4: Security Opt-in Prompt** *(skipped only if the user already explicitly requested Step 7)*:
   - After **Step 6 (QA)** reports `STATUS: PASS`, **STOP** and ask the user whether Security should run:
     > *"QA ha finalizado con `STATUS: PASS`. ¿Deseas que ejecute la auditoría de Seguridad (`Step 7: security`) o pasamos directo al cierre y entrega (`Step 8`)?"*
   - **If the user declines / skips**: proceed directly to **Step 8**.
2. **Execute Fresh Security Audit (`security` subagent, when opted in)**:
   - Initialize `security_retry_count = 0`.
   - Run automated vulnerability/hardening/portability checks and manual security review against `prd.md`, `design.md`, and `architecture.md`; write `agents/context/security-report.md`.
3. **Evaluate Verdict**:
   - If `STATUS: PASS`: proceed to **Step 8**.
   - If `STATUS: FAIL`:
     - Increment `security_retry_count`.
     - **HARD ESCALATION GATE**: If `security_retry_count > 2`, **STOP the autonomous loop** and escalate to the user with `security-report.md` for guidance. (If the user provides direction, reset `security_retry_count = 0` and resume).
     - Otherwise (`security_retry_count <= 2`): Orchestrator invokes `tech-lead` to triage security findings → invokes `dev` to apply fixes and re-run `Step 4.4` → re-run **Step 6 (`qa`)** *(when Step 6 ran in this flow)* → re-run **Step 7 (`security`)**.

---

## Step 8: UAT Delivery, Context Closure & Git Consent (`Gate 5` — Final Gate)

1. **Context Retention** (when `agents/context/` exists):
   - Prepend the completed milestone to `agents/context/history.md` (reverse chronological order, relative links, verified commands).
   - Mark completed phases `🟢` in `agents/context/fases.md`.
2. **Final Portability Check**: Confirm `audit-paths` exits with `0` after final doc/context edits.
3. **User UAT & Git Handoff (`HARD STOP — Gate 5`)**:
   - Present the finished work for user review/UAT, including unit test + `audit-paths` results (and summaries of `code-review.md`, `qa-report.md`, and `security-report.md` when executed).
   - Run `git branch --show-current` and `git status --short` to summarize the ready working tree.
   - **NEVER** run `git commit` or `git push` autonomously; stop here and defer commit formatting and execution to the active Git skill (e.g., `edro-git`) or the user's explicit instructions.

---

## Quick Reference & Assets

| Area | Resource | Purpose |
| :--- | :--- | :--- |
| **Role Prompts** | [`roles/`](roles/) | `product.md`, `design.md`, `tech-lead.md`, `dev.md`, `qa.md`, `security.md` |
| **Context Protocol** | [ref/agents.md](ref/agents.md) | Onboarding gate, artifact contracts, `history.md` formatting |
| **Portability Rules** | [ref/portability.md](ref/portability.md) | Path-agnostic rules and audit remediation |
| **Templates** | [`resources/`](resources/) | `AGENTS.template.md`, `prd.md`, `design.md`, `architecture.md`, `history.md`, `fases.md`, `code-review.md`, `qa-report.md`, `security-report.md` |
| **Audit Scripts** | [scripts/audit-paths.ps1](scripts/audit-paths.ps1), [scripts/audit-paths.sh](scripts/audit-paths.sh) | Automated host-path scanners |
