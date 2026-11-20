# `bulk-branch-mr.ps1`

Crea masivamente una rama nueva (`-NewBranch` o columna `New`) a partir de una rama origen (`Current` de `branches-report.md` generado por [`fetch-branches.ps1`](fetch-branches.md), `-FromMain` o `-SourceBranch`), abre un **Draft MR/PR** auto-detectando **GitLab (`glab`)** o **GitHub (`gh`)**, y baja la rama a local haciendo `git switch`.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- `git` en el `PATH`
- `glab` autenticado (`glab auth login`) para repos de GitLab y/o `gh` autenticado (`gh auth login`) para repos de GitHub

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz donde viven los repositorios. |
| `-ReportFile` | `string` | `branches-report.md` | Reporte generado por `fetch-branches.ps1` (usa `Current` como origen `X`). |
| `-Services` | `string[]` | `@()` | Filtra solo los servicios indicados. |
| `-NewBranch` | `string` | `""` | Nombre único de la rama `Y` a crear. Si se omite, lee la columna `New` de `branches-report.md` (si está vacía o `-`, hace *Skip*). |
| `-Title` | `string` | `Draft: <NewBranch>` | Título del MR/PR. |
| `-Description` | `string` | `""` | Descripción del MR/PR. |
| `-SourceBranch` | `string` | `""` | Fuerza una rama origen `X` única para todos los repos. |
| `-FromMain` | `switch` | `false` | Usa `Main/Master` como origen `X` en vez de `Current`. |
| `-TargetBranch` | `string` | `""` | Rama destino del MR/PR (por defecto la misma `X`). |
| `-Provider` | `string` | `auto` | `auto`, `gh` o `glab` (útil para GitLab self-hosted sin `gitlab` en la URL). |
| `-AllowEmptyCommit` | `switch` | `false` | En GitHub crea un commit vacío para poder abrir el Draft PR de inmediato. |
| `-NoDraft` | `switch` | `false` | Crea el MR/PR listo (sin prefijo/estado Draft). |
| `-NoSwitch` | `switch` | `false` | Crea rama y MR/PR en remoto sin cambiar la rama local. |
| `-DryRun` | `switch` | `false` | Simula la operación sin crear ramas ni MRs/PRs. |
| `-OutFile` | `string` | `bulk-mr-report.md` | Ruta del reporte Markdown de salida. |
| `-Console` | `switch` | `false` | Imprime resultados en consola en lugar de crear el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda de carpetas `.git`. |

## Ejemplos de uso manual

Paso previo (si aún no tienes `branches-report.md`, genéralo con [`fetch-branches.ps1`](fetch-branches.md) y llena la columna `New` en los servicios que quieras procesar):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\fetch-branches.ps1" -Path "D:\Projects\Go"
```

Simular creación leyendo origen (`Current`) y rama nueva (`New`) desde `branches-report.md`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\bulk-branch-mr.ps1" -Path "D:\Projects\Go" -ReportFile "branches-report.md" -DryRun
```

Simular creación usando `Current` de `branches-report.md` como origen `X` y un nombre único `-NewBranch`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\bulk-branch-mr.ps1" -Path "D:\Projects\Go" -ReportFile "branches-report.md" -NewBranch "fix/go-vulns" -DryRun
```

Ejecutar creación de rama + Draft MR/PR y hacer switch en local (saliendo de `Current`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\bulk-branch-mr.ps1" -Path "D:\Projects\Go" -ReportFile "branches-report.md" -NewBranch "fix/go-vulns" -Title "fix/go-vulns: resolve Go vulnerabilities"
```

Salir desde `main`/`master` en servicios específicos (incluyendo commit vacío si son de GitHub):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\bulk-branch-mr.ps1" -Path "D:\Projects\Go" -Services svc-1,svc-2 -FromMain -NewBranch "fix/go-vulns" -AllowEmptyCommit
```

## Comandos equivalentes (manual)

Crear rama remota en GitLab desde origen `X`:

```bash
glab api "projects/:fullpath/repository/branches" -X POST -f "branch=<Y>" -f "ref=<X>"
```

Crear Draft MR en GitLab:

```bash
glab mr create --source-branch <Y> --target-branch <X> --title "Draft: <titulo>" --draft --yes
```

Crear Draft PR en GitHub (requiere al menos 1 commit de diferencia):

```bash
git commit --allow-empty -m "<Y>: init draft PR"
```

```bash
git push -u origin <Y>
```

```bash
gh pr create --base <X> --head <Y> --title "Draft: <titulo>" --draft
```

Bajar la rama remota y cambiar en local:

```bash
git fetch origin <Y>
```

```bash
git switch -c <Y> --track origin/<Y>
```
