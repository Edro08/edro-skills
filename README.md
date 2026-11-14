# edro-skills

Colección de skills y workflows reutilizables para agentes de desarrollo (compatibles con Antigravity y el estándar `SKILL.md`).

## Skills incluidas

| Skill | Descripción | Estado |
| :--- | :--- | :--- |
| [`edro-sdlc`](edro-sdlc/SKILL.md) | Workflow tri-modal:<br>- **Lite Mode**: `Step 0` obligatorio → salto modular a `Step 4` Dev + `Gate 3`, `Step 5` Code Review, `Step 6` QA o `Step 7` Security.<br>- **SDLC Mode**: orquestador `Step 0` → `Step 8` (Product → Design + `Gate 1` → Tech Lead + `Gate 2` → Dev → Code Review + `Gate 3` Consultor → QA → Security Opt-in `Gate 4` → UAT & Git `Gate 5`).<br>- **Docs Mode**: `Full Reverse-Documentation` y `Assisted/Targeted Docs` en solo lectura sobre código, generando `docs/` con `agents/context/fases.md` opcional. | Lista |
| [`edro-git`](edro-git/SKILL.md) | Convenciones de Git: protección de ramas, mensajes `"<branch>: <description>"` y consentimiento explícito antes de commitear o pushear. | Lista |
| [`edro-dev-go`](edro-dev-go/SKILL.md) | Base de estándares, arquitectura idiomática, manejo de errores y testing para proyectos en **Go**. | Base inicial (personalizable) |

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
│   └── SKILL.md      # Convenciones de ramas, commits y consentimiento explícito
└── edro-dev-go/
    ├── SKILL.md
    └── ref/          # Convenciones y patrones de Go
```
