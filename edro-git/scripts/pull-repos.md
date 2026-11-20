# `pull-repos.ps1`

Actualiza de forma segura (`git pull --ff-only`) uno, N o todos los repositorios de un workspace en su rama actual. Salta automáticamente repositorios con cambios sin commitear, sin *upstream* o con historial divergente.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- `git` en el `PATH`

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz donde viven los repositorios. |
| `-Services` | `string[]` | `@()` | Lista de servicios específicos a actualizar (1 o N; vacío = todos). |
| `-ReportFile` | `string` | `""` | Opcional: filtra solo los servicios listados en `branches-report.md` (de [`fetch-branches.ps1`](fetch-branches.md)). |
| `-Stash` | `switch` | `false` | Hace `git stash push -u` si hay cambios locales en vez de saltar el repo. |
| `-DryRun` | `switch` | `false` | Verifica qué repos están `behind` sin modificar archivos locales. |
| `-OutFile` | `string` | `pull-report.md` | Ruta del reporte Markdown de salida. |
| `-Console` | `switch` | `false` | Imprime resultados en consola en lugar de crear el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda de carpetas `.git`. |

## Ejemplos de uso manual

Simular qué repos tienen commits pendientes por bajar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\pull-repos.ps1" -Path "D:\Projects\Go" -DryRun
```

Actualizar todos los repositorios limpios:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\pull-repos.ps1" -Path "D:\Projects\Go"
```

Actualizar solo 1 o N servicios específicos:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\pull-repos.ps1" -Path "D:\Projects\Go" -Services go-archkit,go-utils
```

Actualizar solo los servicios filtrados en `branches-report.md`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\pull-repos.ps1" -Path "D:\Projects\Go" -ReportFile "branches-report.md"
```

## Comandos Git equivalentes (manual)

Actualizar referencias remotas de la rama actual:

```bash
git -C <repo> fetch --quiet
```

Ver cuántos commits está `ahead` / `behind` respecto al remoto:

```bash
git -C <repo> rev-list --left-right --count HEAD...@{u}
```

Verificar si hay cambios locales sin commitear:

```bash
git -C <repo> status --porcelain
```

Actualizar en fast-forward sin crear merges automáticos:

```bash
git -C <repo> pull --ff-only --quiet
```
