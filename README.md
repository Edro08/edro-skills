# edro-skills

Colección de skills y workflows reutilizables para agentes de desarrollo (compatibles con Antigravity y el estándar `SKILL.md`).

## Skills incluidas

| Skill | Descripción | Estado |
| :--- | :--- | :--- |
| [`edro-sdlc`](edro-sdlc/SKILL.md) | Workflow tri-modal:<br>- **Lite Mode**: `Step 0` obligatorio → salto modular a `Step 4` Dev + `Gate 3`, `Step 5` Code Review, `Step 6` QA o `Step 7` Security.<br>- **SDLC Mode**: orquestador `Step 0` → `Step 8` (Product → Design + `Gate 1` → Tech Lead + `Gate 2` → Dev → Code Review + `Gate 3` Consultor → QA → Security Opt-in `Gate 4` → UAT & Git `Gate 5`).<br>- **Docs Mode**: `Full Reverse-Documentation` y `Assisted/Targeted Docs` en solo lectura sobre código, generando `docs/` con `agents/context/fases.md` opcional. | Lista |
| [`edro-git`](edro-git/SKILL.md) | Convenciones de Git: protección de ramas, mensajes `"<branch>: <description>"`, prohibición de co-autores, consentimiento explícito antes de commitear/pushear y scripts multi-repo (`fetch-branches`, `switch-branches`, `pull-repos`, `clean-branches`, `bulk-branch-mr`). | Lista |
| [`edro-dev-go`](edro-dev-go/SKILL.md) | Estándares idiomáticos, arquitectura, manejo de errores, testing en **Go** y utilidades multi-servicio (`fix-go-vulns` con `govulncheck`, `test-go-repos` con `go vet` + `go test`). | Lista |
| [`edro-workspace`](edro-workspace/SKILL.md) | Inspección rápida y de bajo consumo de tokens para detectar el stack tecnológico de los servicios de un workspace (`detect-services`). | Lista |

## Estructura del repositorio

```text
edro-skills/
├── README.md
├── .gitignore
├── edro-sdlc/
│   ├── SKILL.md
│   ├── references/   # Regla transversal de portabilidad (portability.md)
│   ├── resources/    # Plantillas para AGENTS.md, docs/* y agents/context/*
│   ├── roles/        # Prompts aislados por rol SDLC
│   └── scripts/      # Auditores de portabilidad (PowerShell / Bash)
├── edro-git/
│   ├── SKILL.md      # Convenciones de ramas, commits (sin co-autores) y consentimiento explícito
│   └── scripts/      # fetch-branches, switch-branches, pull-repos, clean-branches, bulk-branch-mr (.ps1 + .md)
├── edro-dev-go/
│   ├── SKILL.md
│   ├── ref/          # Convenciones y patrones de Go
│   └── scripts/      # fix-go-vulns, test-go-repos (.ps1 + .md)
└── edro-workspace/
    ├── SKILL.md
    └── scripts/      # detect-services (.ps1 + .md)
```
