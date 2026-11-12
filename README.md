# edro-skills

Colección de skills y workflows reutilizables para agentes de desarrollo (compatibles con Antigravity y el estándar `SKILL.md`).

## Skills incluidas

| Skill | Descripción | Estado |
| :--- | :--- | :--- |
| [`edro-sdlc`](edro-sdlc/SKILL.md) | Workflow dual: **Lite Mode** (single-agent para fixes/onboarding/Git/portabilidad) y **SDLC Mode** (orquestador multi-rol: Product → Design → Tech Lead/Architect → Dev → QA → Security con `Max Retries = 2` → UAT). | Lista |
| [`edro-dev-go`](edro-dev-go/SKILL.md) | Base de estándares, arquitectura idiomática, manejo de errores y testing para proyectos en **Go**. | Base inicial (personalizable) |

## Estructura del repositorio

```text
edro-skills/
├── README.md
├── .gitignore
├── edro-sdlc/
│   ├── SKILL.md
│   ├── ref/          # Protocolos transversales (agents, git, portability)
│   ├── resources/    # Plantillas para AGENTS.md y agents/*
│   ├── roles/        # Prompts aislados por rol SDLC
│   └── scripts/      # Auditores de portabilidad (PowerShell / Bash)
└── edro-dev-go/
    ├── SKILL.md
    └── ref/          # Convenciones y patrones de Go
```

## Instalación / Uso

Copia o enlaza la carpeta de cada skill dentro de tu directorio de configuración global o del proyecto:

- **Global (todos los proyectos)**:
  - `~/.gemini/config/skills/<skill-name>/`
- **Por proyecto (versionado con el equipo)**:
  - `<repo-root>/.agents/skills/<skill-name>/`

Una vez instalada, el agente la detecta automáticamente según la tarea o puedes invocarla con `/edro-sdlc` o `/edro-dev-go`.
