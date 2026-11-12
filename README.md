# edro-skills

Colección de skills y workflows reutilizables para agentes de desarrollo (compatibles con Antigravity y el estándar `SKILL.md`).

## Skills incluidas

| Skill | Descripción | Estado |
| :--- | :--- | :--- |
| [`edro-sdlc`](edro-sdlc/SKILL.md) | Workflow dual: **Lite Mode** (single-agent para fixes/onboarding/portabilidad) y **SDLC Mode** (orquestador multi-rol: Product → Design → Tech Lead/Architect → Dev → QA → Security con `Max Retries = 2` → UAT). | Lista |
| [`edro-git`](edro-git/SKILL.md) | Convenciones de Git: protección de ramas, mensajes `"<branch>: <description>"` y consentimiento explícito antes de commitear o pushear. | Lista |
| [`edro-dev-go`](edro-dev-go/SKILL.md) | Base de estándares, arquitectura idiomática, manejo de errores y testing para proyectos en **Go**. | Base inicial (personalizable) |

## Estructura del repositorio

```text
edro-skills/
├── README.md
├── .gitignore
├── edro-sdlc/
│   ├── SKILL.md
│   ├── ref/          # Protocolos transversales (agents, portability)
│   ├── resources/    # Plantillas para AGENTS.md y agents/*
│   ├── roles/        # Prompts aislados por rol SDLC
│   └── scripts/      # Auditores de portabilidad (PowerShell / Bash)
├── edro-git/
│   └── SKILL.md      # Convenciones de ramas, commits y consentimiento explícito
└── edro-dev-go/
    ├── SKILL.md
    └── ref/          # Convenciones y patrones de Go
```
