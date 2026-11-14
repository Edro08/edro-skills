---
name: edro-sdlc
description: >-
  Edro's tri-mode engineering skill and multi-role SDLC workflow. Runs in
  Lite Mode (mandatory Step 0 router -> jump to Step 4 Dev + mandatory Gate 3,
  Step 5 Code Review, Step 6 QA, or Step 7 Security), SDLC Mode (multi-role
  orchestrator via `/edro-sdlc`: Step 0 Onboarding -> Step 1 Product -> Step 2
  Design + Gate 1 -> Step 3 Tech Lead + Gate 2 -> Step 4 Dev -> Step 5 Code
  Review + Gate 3 Consultant -> Step 6 QA -> Step 7 Opt-in Security -> Step 8
  UAT & Git Consent), or Docs Mode (read-only reverse-documentation of an
  existing codebase into `docs/` with optional `agents/context/fases.md`),
  enforcing branch safety, context tracking, portability audits, and explicit
  Git commit consent.
---

# Edro SDLC & Dev Standards Workflow

This skill supports **three execution modes**. Pick the lightest mode that fits the task (or follow the user's explicit request):

| Mode | When to Use | How It Executes |
| :--- | :--- | :--- |
| **Lite Mode** *(Modular Router)* | Small bugfixes, minor refactors, standalone code reviews, targeted QA/Security runs, repo onboarding, or tasks not needing PRD/mockups | **Step 0 (`Gate 0`) is always mandatory**. From Step 0, jump to **`Step 4` (Dev)**, **`Step 5` (Code Review)**, **`Step 6` (QA)**, or **`Step 7` (Security)**. **Whichever step (`4`, `5`, `6`, or `7`) runs in Lite Mode triggers `Gate 3` (Tech Lead Consultant) on completion (`PASS` or `FAIL`)**—never auto-remediating without your direction—until you approve moving to **`Step 8`**. |
| **SDLC Mode** *(Multi-Role)* | New features, product/UI/API/CLI design, substantial architecture changes, or explicit full-cycle `/edro-sdlc` requests | Act as the **Orchestrator** coordinating clean role subagents (Option A) via `docs/` & `agents/context/` handoff contracts from **`Step 0` → `Step 8`**. Never merge `dev` with `qa` or `security`. |
| **Docs Mode** *(Reverse & Assisted Docs)* | Existing codebase lacking specs/mockups (**Full Reverse-Docs**), or creating targeted specs/mockups from scratch or for a specific module (**Assisted Docs**) without modifying code | **Read-only on application code**. Step 0 asks for **(A) Variant** (*Full Reverse-Docs* vs *Assisted/Targeted Docs* for what the user specifies) and **(B) Output Scope** (*`docs/` only*, *`docs/` + `AGENTS.md` + `agents/context/`*, or *scratch export*). Runs only the needed doc role(s) → **`Gate 3`** → `audit-paths` → **`Step 8`**. |

```text
[Lite Mode]:  [0. Git & Onboarding (Mandatory)]
                 ├──▶ [4. Dev + Tests + audit-paths] ──┐
                 ├──▶ [5. Code Review direct] ─────────┼──▶ ✋ GATE 3 (Tech Lead Consultant — Always triggered):
                 ├──▶ [6. QA direct] ──────────────────┤       ├── Request changes / remediation ──▶ [4. Dev] / loop
                 └──▶ [7. Security direct] ────────────┘       ├── Trigger another step ──▶ [5] / [6] / [7]
                                                               └── Approve ("todo bien") ──▶ [8. Closure & Git]

[Docs Mode]:  [0. Variant + Output Scope: Full Reverse-Docs vs Assisted/Targeted | docs/ only vs +fases.md vs scratch]
                 ├─ Full Reverse-Docs ─▶ [product: prd.md] ─▶ [design: design.md + mockups/*] ─▶ [tech-lead: architecture.md (+ fases.md)]
                 └─ Assisted / Targeted ─▶ [Only requested doc/mockup/spec role(s) from scratch or target module]
                 ──▶ ✋ GATE 3 (Review docs & mockups) ─▶ [audit-paths] ─▶ [8. Closure / Git (if repo files written)]

[SDLC Mode]:  [0. Git & Onboarding] ─▶ [1. Product (prd.md)] ─▶ [2. Design (docs/*)] ─▶ ✋ GATE 1: User approves mockups
                                                                                                      │
                 ┌────────────────────────────────────────────────────────────────────────────────────┘
                 ▼
              [3. Tech Lead / Architect] ─▶ ✋ GATE 2 (Tech Lead Consultant, if substantial) ─▶ [4. Dev (implements + tests + audit-paths)]
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
              ✋ GATE 4 (Security Opt-in): Ask Tech Lead Consultant whether to run Step 7 (Security) or skip to Step 8
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
| Review hand-written or uncommitted code (`Code Review` only) | **Lite Mode**: **Step 0** → **Step 5** (`tech-lead` writes `code-review.md`) → **`Gate 3`** (**Tech Lead Consultant** decides next step) → **Step 8** |
| Test / verify existing features or changes (`QA` only) | **Lite Mode**: **Step 0** → **Step 6** (`qa` writes `qa-report.md`) → **`Gate 3`** (**Tech Lead Consultant** decides remediation, `Step 7`, or close) → **Step 8** |
| Audit vulnerabilities, hardening, or portability (`Security` only) | **Lite Mode**: **Step 0** → **Step 7** (`security` writes `security-report.md`) → **`Gate 3`** (**Tech Lead Consultant** decides remediation or close) → **Step 8** |
| Close an already-reviewed task (`audit-paths`, `history.md`, `fases.md`, Git) | **Lite Mode**: **Step 4.4 → Step 8** |
| New feature / product idea / UI, API, or CLI design | **SDLC Mode**: **Step 0 → Step 8** (full pipeline) |
| Architecture or dev implementation with specs already approved | **SDLC Mode**: **Step 0 → Step 3 → Step 8** |
| Document an existing codebase or create targeted specs/mockups from scratch (`read-only` on code) | **Docs Mode**: **Step 0 (Variant + Scope)** → Full (`product` + `design` + `tech-lead`) or Assisted (requested role/doc only) → **`Gate 3`** → **Step 8** |

---

## Subagent Setup (Option A)

Define/invoke clean role subagents on demand (`define_subagent` with `EnableWriteTools: true`, `EnableSubagentTools: false` + `invoke_subagent`), passing each subagent **its role file** plus **only the relevant input artifact paths** in `agents/` (or `<Artifact Directory Path>/scratch/agents/` if the user declined repo onboarding in Step 0):

| Subagent Role | Role Prompt | Write Scope Boundary | Primary Output Contract |
| :--- | :--- | :--- | :--- |
| `product` | [roles/product.md](roles/product.md) | Only `docs/specs/prd.md` (no source code) | `docs/specs/prd.md` |
| `design` | [roles/design.md](roles/design.md) | Only `docs/specs/*` & `docs/mockups/*` (no source code) | `docs/specs/design.md` + `.png`/`.svg`/`.html` mockups |
| `tech-lead` | [roles/tech-lead.md](roles/tech-lead.md) | Only `docs/specs/architecture.md`, `agents/context/fases.md`, & `agents/context/code-review.md` | `architecture.md`, `fases.md`, & `code-review.md` (`STATUS: PASS \| FAIL`) |
| `dev` | [roles/dev.md](roles/dev.md) | Full repo + scripts + `agents/context/fases.md` | Code, unit tests, progress reports, `audit-paths` clean |
| `qa` | [roles/qa.md](roles/qa.md) | Only test execution + `agents/context/qa-report.md` (no code edits) | `agents/context/qa-report.md` (`STATUS: PASS \| FAIL`) |
| `security` | [roles/security.md](roles/security.md) | Only scanners + `agents/context/security-report.md` (no code edits) | `agents/context/security-report.md` (`STATUS: PASS \| FAIL`) |

> **Orchestrator, Portability & Anti-bias rules**:
> - **Global Portability Rule ([references/portability.md](references/portability.md))**: Applies across **all 3 modes** (`Lite`, `SDLC`, `Docs`) and **all roles** (`product`, `design`, `tech-lead`, `dev`, `qa`, `security`)—never write hardcoded host paths (`C:\...`, `/Users/...`, `/home/...`, `file:///`) into repo code, scripts, tests, specs, or `agents/context/` reports.
> - **Resolved Artifact Root**: The Orchestrator resolves the effective artifact root in Step 0 (repository root when repo onboarding is enabled, or `<Artifact Directory Path>/scratch/` when declined) and passes the resolved target paths to each subagent.
> - **Orchestrator owns user communication & invocation**: Subagents return their artifacts and summaries to the Orchestrator; the Orchestrator presents all questions/Gates (`Gate 0`–`Gate 5`) to the user and invokes the next subagent.
> - **Fresh verification contexts**: Always launch `qa` and `security` as **fresh subagents** so they verify against `prd.md`, `design.md`, `architecture.md`, and real execution—never inheriting `dev`'s assumptions.

---

## Step 0: Git Preflight & Project Onboarding (`Gate 0` — Mandatory in Both Modes)

1. **Branch Safety Preflight**:
   - Run `git rev-parse --is-inside-work-tree`, `git branch --show-current`, and `git status --short`.
   - **HARD GATE**: If on `main` or `master` and files will be modified, **STOP** and ask the user to create/switch to a dedicated branch (or follow the active Git skill such as `edro-git`).
2. **Context Onboarding**:
   - Check for root `AGENTS.md`, `docs/` (`specs/`, `mockups/`), and `agents/context/`.
   - If missing, **STOP** and ask verbatim:
     > *"He notado que este proyecto aún no cuenta con `AGENTS.md` ni la estructura de contexto en `agents/`. ¿Deseas que los configure ahora para llevar el registro de fases, historial de cambios y arquitectura?"*
   - If approved, scaffold base templates from [`resources/`](resources/).
   - If declined, do **not** create `AGENTS.md`, `docs/`, or `agents/` in the repository; instead, route all role handoff files (`docs/*` and `agents/context/*` reports) under `<Artifact Directory Path>/scratch/` for the duration of the session.
   - If already present, read `AGENTS.md` and current `agents/context/fases.md` / top of `agents/context/history.md`.
3. **Lite Mode Step Selection (when running in Lite Mode)**:
   - Route directly to the target step requested by the user (**`Step 4` Dev**, **`Step 5` Code Review**, **`Step 6` QA**, or **`Step 7` Security**). If ambiguous, ask which step to run.

---

## Step 1: Product Definition (`product`)

1. Invoke the `product` subagent to analyze the user request and identify ambiguities.
2. If `product` surfaces open questions, the Orchestrator presents them concisely to the user and passes the answers back to `product` before finalizing scope.
3. Produce `docs/specs/prd.md` with clear **In Scope**, **Out of Scope**, and testable **Acceptance Criteria**.

---

## Step 2: Design & Mockups (`design` + `Gate 1`)

1. Invoke the `design` subagent with `docs/specs/prd.md`.
2. Store mockups in `docs/mockups/` (`.png`, `.svg`, HTML mockups) and API/CLI contracts in `docs/specs/` (`.json`, `.yaml`), summarizing them in `docs/specs/design.md`.
3. **HARD GATE 1 (User Design Sign-off)**:
   - The Orchestrator presents the base design and mockups to the user.
   - Debate improvements and iterate with `design` (and `product` if scope shifts) until the user explicitly approves the concrete target.

---

## Step 3: Architecture & Phase Planning (`tech-lead` + `Gate 2`)

1. Invoke the merged `tech-lead` subagent (Tech Lead + Architect) with `prd.md` and `design.md`.
2. Update `docs/specs/architecture.md` and break work into phases in `agents/context/fases.md`.
3. **GATE 2 (Tech Lead Consultant)**: For substantial features or architectural shifts, the Orchestrator presents `architecture.md` and `fases.md` to the **Tech Lead Consultant** for alignment before coding.

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
     - UI/Endpoint/CLI change → `design` updates `design.md` / `docs/mockups/*` / `docs/specs/*` (+ quick user sign-off at `Gate 1`).
     - Architecture or phase shift → `tech-lead` updates `architecture.md` and re-plans `fases.md`.
4. **Portability & Unit Test Gate (`Step 4.4`)**: `dev` must verify unit tests pass and run the `audit-paths` scanner from [references/portability.md](references/portability.md) with `exit 0`.
5. **Transition from Step 4**:
   - In **SDLC Mode**: proceed to **Step 5** (`5.1` autonomous `tech-lead` review → `5.2 Gate 3`).
   - In **Lite Mode**: proceed directly to **`Gate 3` (`Step 5.2`)**, presenting the technical summary to the user (who may request changes, trigger full `Step 5` / `Step 6` / `Step 7` on demand, or approve to jump to **Step 8**).

---

## Step 5: Code & Architecture Review (`tech-lead` + `Gate 3: Tech Lead Consultant`)

Initialize `review_retry_count = 0`. Working notes, review findings, and consultant iterations are tracked in `agents/context/code-review.md` ([resources/code-review.md](resources/code-review.md)).

1. **5.1 Autonomous Review Loop (`tech-lead ⇄ dev`, `review_retry_count <= 2`)**:
   - The Orchestrator invokes `tech-lead` to review `dev`'s diff against `architecture.md`, `prd.md`, `design.md`, `fases.md` (when present), and stack standards (e.g., `edro-dev-*`), recording findings in `agents/context/code-review.md`.
   - **If entered directly in Lite Mode (`Step 0 → Step 5`)**: do **not** run autonomous `dev` edits—proceed straight to **`Gate 3` (`5.2`)** with `code-review.md`.
   - **In SDLC Mode**: if issues are found:
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
     - `tech-lead` marks `STATUS: PASS` in `agents/context/code-review.md` and **integrates/consolidates all final changes into `docs/specs/architecture.md` and `agents/context/fases.md`**.
     - If any consultant-requested change altered external UX/CLI/API contracts or scope, sync `design.md` / `prd.md` so **Step 6 (QA)** validates against accurate specs.
   - Proceed to **Step 6 (QA Verification)** in SDLC Mode (or to **Step 8** in Lite Mode unless the user requested Step 6/7).

---

## Step 6: QA Verification (`qa`, `Max Retries = 2`)

Initialize `qa_retry_count = 0`.

1. **Execute Fresh QA (`qa` subagent)**:
   - Run real integration and end-to-end checks against `prd.md` and `design.md` (or against codebase contracts and user test goals in Lite Mode); write `agents/context/qa-report.md`.
2. **Evaluate Verdict**:
   - **If entered directly in Lite Mode (`Step 0 → Step 6`)**: regardless of `PASS` or `FAIL`, **STOP** before editing code and report `qa-report.md` to the **Tech Lead Consultant (`Gate 3`)**, who decides whether to trigger remediation (`tech-lead → dev → Step 4.4 → Step 6`), run **Step 7 (`Security`)**, or approve moving to **Step 8**.
   - **In SDLC Mode (or when triggered from `Gate 3` after `Step 4`)**:
     - If `STATUS: PASS`: proceed to **Step 7 (`Gate 4`: Security Opt-in)**.
     - If `STATUS: FAIL`:
       - Increment `qa_retry_count`.
       - **HARD ESCALATION GATE**: If `qa_retry_count > 2`, **STOP the autonomous loop** and escalate to the **Tech Lead Consultant** with `qa-report.md` for guidance. (If direction is provided, reset `qa_retry_count = 0` and resume).
       - Otherwise (`qa_retry_count <= 2`): Orchestrator invokes `tech-lead` to triage defects → invokes `dev` to apply fixes → re-run **Step 6 (`qa`, fresh subagent)**.

---

## Step 7: Security Audit (`Gate 4 Opt-in` + `security`, `Max Retries = 2`)

1. **✋ GATE 4: Security Opt-in Prompt** *(skipped only if already explicitly requested Step 7)*:
   - After **Step 6 (QA)** reports `STATUS: PASS`, **STOP** and ask the **Tech Lead Consultant** whether Security should run:
     > *"QA ha finalizado con `STATUS: PASS`. ¿Deseas que ejecute la auditoría de Seguridad (`Step 7: security`) o pasamos directo al cierre y entrega (`Step 8`)?"*
   - **If declined / skipped**: proceed directly to **Step 8**.
2. **Execute Fresh Security Audit (`security` subagent, when opted in)**:
   - Initialize `security_retry_count = 0`.
   - Run automated vulnerability/hardening/portability checks and manual security review against `prd.md`, `design.md`, and `architecture.md`; write `agents/context/security-report.md`.
3. **Evaluate Verdict**:
   - **If entered directly in Lite Mode (`Step 0 → Step 7`)**: regardless of `PASS` or `FAIL`, **STOP** before editing code and report `security-report.md` to the **Tech Lead Consultant (`Gate 3`)**, who decides whether to trigger remediation (`tech-lead → dev → Step 4.4` + optional `Step 6` QA → `Step 7` re-audit) or approve moving to **Step 8**.
   - **In SDLC Mode (or when triggered from `Gate 3` after `Step 4`)**:
     - If `STATUS: PASS`: proceed to **Step 8**.
     - If `STATUS: FAIL`:
       - Increment `security_retry_count`.
       - **HARD ESCALATION GATE**: If `security_retry_count > 2`, **STOP the autonomous loop** and escalate to the **Tech Lead Consultant** with `security-report.md` for guidance. (If direction is provided, reset `security_retry_count = 0` and resume).
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

## Docs Mode Execution (Full Reverse-Docs & Assisted Docs)

Use **Docs Mode** when the user wants documentation or mockups generated **without modifying application source code**:

1. **Step 0 — Variant & Output Scope Prompt (Mandatory)**:
   - Check branch safety (if repo files will be written).
   - Confirm **which Docs variant** applies (if not already explicit in the user's prompt):
     - **Full Reverse-Documentation**: analyze the entire existing codebase and generate the full baseline (`prd.md`, `design.md` + `docs/mockups/*`, `architecture.md`).
     - **Assisted / Targeted Docs**: create specific documentation from scratch or for a user-specified module/topic (e.g., a single `spec_*.md`, one mockup in `docs/mockups/`, `architecture.md` for a subsystem, or a standalone `prd.md`).
   - **STOP and ask the user explicitly** where to place the output:
     > *"En **Docs Mode** no modificaré el código fuente. ¿Cómo quieres generar la documentación?"*
     > 1. **Solo `docs/`** (`docs/specs/` + `docs/mockups/`, sin crear `AGENTS.md` ni `agents/context/fases.md` — ideal si solo quieres la documentación o usarla en otra parte).
     > 2. **Completo (`docs/` + `AGENTS.md` + `agents/context/`)** (incluye `fases.md` con lo ya implementado en `🟢` y pendientes en `⚪`, más `history.md`).
     > 3. **Solo exportación temporal** (guardar en `<Artifact Directory Path>/scratch/docs/` sin tocar el repositorio).
2. **Documentation Execution (`read-only` on source code)**:
   - **If Full Reverse-Documentation**:
     - `product` → inspects implemented features and writes `docs/specs/prd.md`.
     - `design` → inspects existing UI/API/CLI code and generates `docs/specs/design.md` + missing mockups/contracts in `docs/mockups/` and `docs/specs/`.
     - `tech-lead` → inspects codebase structure and writes `docs/specs/architecture.md` (and `agents/context/fases.md` **only if** the user chose Option 2).
   - **If Assisted / Targeted Docs**:
     - Clarify any missing details with the user if creating from scratch, then run **only** the matching role(s) (`product`, `design`, or `tech-lead`) to produce the exact requested spec/mockup/doc (plus `fases.md` **only if** Option 2 was chosen).
3. **Review, Portability & Closure**:
   - Present generated docs/mockups at **`Gate 3`** for user review and iterate if requested.
   - Run `audit-paths` on the generated files (`Step 4.4`).
   - Run **Step 8** (update `history.md` only if `agents/context/` was opted in; ask for Git consent only if repository files were written).

---

## Quick Reference & Assets

| Area | Resource | Purpose |
| :--- | :--- | :--- |
| **Role Prompts** | [`roles/`](roles/) | `product.md`, `design.md`, `tech-lead.md`, `dev.md`, `qa.md`, `security.md` |
| **Portability Rules** | [references/portability.md](references/portability.md) | Path-agnostic rules and audit remediation |
| **Templates** | [`resources/`](resources/) | `AGENTS.template.md`, `prd.md`, `design.md`, `architecture.md`, `history.md`, `fases.md`, `code-review.md`, `qa-report.md`, `security-report.md` |
| **Audit Scripts** | [scripts/audit-paths.ps1](scripts/audit-paths.ps1), [scripts/audit-paths.sh](scripts/audit-paths.sh) | Automated host-path scanners |

### Scaffolding Mapping (Target Path ← Template)

| Target Path | Template Source | Owner Role | Update Protocol |
| :--- | :--- | :--- | :--- |
| `AGENTS.md` | [resources/AGENTS.template.md](resources/AGENTS.template.md) | Orchestrator | Copy as repo root `AGENTS.md`; update when repo-wide specs or agent contracts change. |
| `docs/specs/prd.md` | [resources/prd.md](resources/prd.md) | `product` | Created/updated in Step 1 (or Docs Mode). |
| `docs/specs/design.md` | [resources/design.md](resources/design.md) | `design` | Created/updated in Step 2 (or Docs Mode) alongside mockups in `docs/mockups/` & contracts in `docs/specs/`. |
| `docs/specs/architecture.md` | [resources/architecture.md](resources/architecture.md) | `tech-lead` | Updated in Step 3 (or Docs Mode) and consolidated at `Gate 3`. |
| `agents/context/fases.md` | [resources/fases.md](resources/fases.md) | `tech-lead` / `dev` | Track `🟢` / `🟡` / `⚪`; consolidated at `Gate 3` and closed in Step 8. |
| `agents/context/code-review.md` | [resources/code-review.md](resources/code-review.md) | `tech-lead` | Active log during Step 5 + `Gate 3`; marked `STATUS: PASS` on approval. |
| `agents/context/history.md` | [resources/history.md](resources/history.md) | `dev` / Orchestrator | Prepend completed milestone at the **top** (reverse chronological order) in Step 8. |
| `agents/context/qa-report.md` | [resources/qa-report.md](resources/qa-report.md) | `qa` | Updated in Step 6 with binary `STATUS: PASS \| FAIL`. |
| `agents/context/security-report.md` | [resources/security-report.md](resources/security-report.md) | `security` | Updated in Step 7 (when opted in at `Gate 4`) with binary `STATUS: PASS \| FAIL`. |
