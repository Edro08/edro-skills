# Project Context & Agents Protocol

This reference defines the protocol for repository initialization, SDLC spec/report contracts, context retention, and agent tracking across all projects.

---

## 1. Onboarding Check (New Task / Project Start)

Before modifying code on a new feature, refactor, or substantial task, verify the project's context layout:

1. **Root Contract**: Check for `AGENTS.md` at the repository root.
2. **Context Ecosystem**: Check for `agents/` containing:
   - `agents/specs/` (`prd.md`, `design.md`, `architecture.md`, and design artifacts such as `.png`, `.svg`, `.json`, `.html`)
   - `agents/context/` (`history.md`, `fases.md`, `qa-report.md`, `security-report.md`)

---

## 2. Interaction Gate (Prompting the User)

If `AGENTS.md` or the `agents/` structure is missing:

- **DO NOT** create them silently or proceed without asking.
- **STOP and prompt the user explicitly**:
  > *"He notado que este proyecto aún no cuenta con `AGENTS.md` ni la estructura de contexto en `agents/`. ¿Deseas que los configure ahora para llevar el registro de fases, historial de cambios y arquitectura?"*

- **Outcomes**:
  - **User approves** (*"Sí"*, *"Dale"*, *"Créalo"*): Scaffold core files from `resources/` (below), replace placeholders (`[ProjectName]`, `YYYY-MM-DD`, initial phase), and confirm the created files before proceeding. Spec/report templates (`prd.md`, `design.md`, `qa-report.md`, `security-report.md`) can be created upfront or when their corresponding SDLC step runs.
  - **User declines** (*"No"*, *"Por ahora no"*): Respect the decision—do **not** create `AGENTS.md` or `agents/` inside the repository. Route all role handoff artifacts (`specs/*` and `context/*` reports) to `<Artifact Directory Path>/scratch/agents/` for the current session and skip repository context updates in Step 6.

---

## 3. Scaffolding Mapping & Update Rules

| Target Path | Template Source | Owner Role | Update Protocol |
| :--- | :--- | :--- | :--- |
| `AGENTS.md` | [`../resources/AGENTS.template.md`](../resources/AGENTS.template.md) | Orchestrator | Copy as repo root `AGENTS.md`; update when repo-wide specs or agent contracts change. |
| `agents/specs/prd.md` | [`../resources/prd.md`](../resources/prd.md) | `product` | Created/updated in Step 1 (Product Definition). |
| `agents/specs/design.md` | [`../resources/design.md`](../resources/design.md) | `design` | Created/updated in Step 2 alongside `.png`/`.svg`/`.json`/`.html` mockups in `agents/specs/`. |
| `agents/specs/architecture.md` | [`../resources/architecture.md`](../resources/architecture.md) | `tech-lead` | Updated in Step 3 when introducing modules, boundaries, or env contracts. |
| `agents/context/fases.md` | [`../resources/fases.md`](../resources/fases.md) | `tech-lead` / `dev` | Move items across `🟢 Fases completadas`, `🟡 Fases en progreso`, and `⚪ Fases planificadas`. |
| `agents/context/history.md` | [`../resources/history.md`](../resources/history.md) | `dev` / Orchestrator | Prepend new entry at the **top** (reverse chronological order) after verified completion. |
| `agents/context/qa-report.md` | [`../resources/qa-report.md`](../resources/qa-report.md) | `qa` | Updated on every QA cycle with binary `STATUS: PASS \| FAIL`. |
| `agents/context/security-report.md` | [`../resources/security-report.md`](../resources/security-report.md) | `security` | Updated on every Security cycle with binary `STATUS: PASS \| FAIL`. |

### Entry Format for `agents/context/history.md`

- Must start with `# Historial de [ProjectName]`.
- Keep sections sorted in **reverse chronological order** (most recent on top):
  ```markdown
  ## YYYY-MM-DD — Fase X: Título del hito
  - **Detalle de cambios ([`ruta/al/archivo.ext`](../../ruta/al/archivo.ext))**:
    - Explicación concisa y técnica del cambio.
  - **Verificación**:
    - Comandos de prueba, builds o auditorías ejecutadas con resultado exitoso.
  ```
- **Strictly relative links**: Every link inside `agents/context/*.md` must resolve relative to that file (e.g., `../../src/main.go`), never using `file:///` or drive letters.
