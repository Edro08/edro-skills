# `switch-branches.ps1`

Cambia de rama de forma segura en múltiples repositorios Git a partir de `branches-report.md` (columna `Current`) o usando una regla directa (`-TargetMain` o `-Branch`). Por defecto omite repositorios con cambios sin commitear.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- `git` en el `PATH`

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz donde viven los repositorios. |
| `-ReportFile` | `string` | `branches-report.md` | Reporte Markdown generado por `fetch-branches.ps1`. |
| `-Services` | `string[]` | `@()` | Filtra solo los servicios indicados. |
| `-Branch` | `string` | `""` | Rama objetivo explícita para todos los repos seleccionados. |
| `-TargetMain` | `switch` | `false` | Cambia cada repo a su rama `main` o `master`. |
| `-Pull` | `switch` | `false` | Ejecuta `git pull --ff-only` después de cambiar (o si ya está en la rama). |
| `-Stash` | `switch` | `false` | Hace `git stash push -u` si hay cambios locales en vez de saltar el repo. |
| `-DryRun` | `switch` | `false` | Simula los cambios sin modificar ningún repositorio. |
| `-OutFile` | `string` | `switch-report.md` | Ruta del reporte Markdown de resultados. |
| `-Console` | `switch` | `false` | Imprime resultados en consola en lugar de generar el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda de carpetas `.git`. |

## Ejemplos de uso manual

Simular cambio según la columna `Current` editada en `branches-report.md`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\switch-branches.ps1" -Path "D:\Projects\Go" -ReportFile "branches-report.md" -DryRun
```

Pasar todos los servicios limpios a `main`/`master` y hacer `pull`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\switch-branches.ps1" -Path "D:\Projects\Go" -TargetMain -Pull
```

Mover servicios puntuales a una rama de sprint:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\switch-branches.ps1" -Path "." -Services svc-1,svc-2 -Branch "sprint/24"
```

## Comandos Git equivalentes (manual)

Ver rama actual:

```bash
git -C <repo> branch --show-current
```

Verificar si hay cambios locales sin commitear:

```bash
git -C <repo> status --porcelain
```

Guardar cambios locales temporalmente (opcional con `-Stash`):

```bash
git -C <repo> stash push -u -m "switch-branches"
```

Cambiar a una rama local existente:

```bash
git -C <repo> switch <target>
```

Crear rama local con tracking si solo existe en `origin`:

```bash
git -C <repo> switch -c <target> --track origin/<target>
```

Actualizar la rama tras cambiar (opcional con `-Pull`):

```bash
git -C <repo> pull --ff-only
```
