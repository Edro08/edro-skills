# `fetch-branches.ps1`

Ejecuta `git fetch --all --prune` en uno o varios repositorios de un workspace y clasifica sus ramas en: `Current`, `Main/Master`, `Intermediate`, `Tasks` y `Other`. Por defecto genera una tabla Markdown (`branches-report.md`).

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- `git` en el `PATH`

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz donde viven los repositorios (o un repo individual). |
| `-Services` | `string[]` | `@()` | Lista de carpetas/servicios específicos a procesar (vacío = todos). |
| `-OutFile` | `string` | `branches-report.md` | Ruta del archivo Markdown de salida. |
| `-NoFetch` | `switch` | `false` | Omite `git fetch` y solo consulta las ramas ya cacheadas en local. |
| `-Console` | `switch` | `false` | Imprime el resumen en consola en lugar de escribir el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda de carpetas `.git`. |

## Ejemplos de uso manual

Fetch + reporte Markdown de todos los servicios en la ruta:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\fetch-branches.ps1" -Path "D:\Projects\Go"
```

Solo algunos servicios específicos:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\fetch-branches.ps1" -Path "D:\Projects\Go" -Services svc-1,svc-2
```

Consultar ramas locales/remotas cacheadas sin ir a red:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\fetch-branches.ps1" -Path "." -NoFetch -Console
```

## Comandos Git equivalentes (manual)

Actualizar referencias remotas y limpiar ramas borradas:

```bash
git -C <repo> fetch --all --prune --quiet
```

Ver rama actual:

```bash
git -C <repo> branch --show-current
```

Listar todas las ramas locales y remotas:

```bash
git -C <repo> branch -a --format="%(refname:short)"
```

Clasificación de ramas:
- **Main/Master:** `main`, `master`
- **Intermediate:** `sprint*`, `release*`, `develop`, `dev`, `staging`, `qa`, `uat`, `preprod`
- **Tasks:** `feat/*`, `feature/*`, `fix/*`, `bug/*`, `bugfix/*`, `hotfix/*`, `task/*`, `chore/*`, `TASK-*` (y variantes con `-` o `_`)
