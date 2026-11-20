# `clean-branches.ps1`

Detecta y elimina de forma segura (`git branch -d`) ramas locales cuyo tracking remoto ya fue borrado (`[gone]`) en uno o varios repositorios. Nunca borra `main`, `master`, `develop` ni la rama actual.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- `git` en el `PATH`

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz donde viven los repositorios. |
| `-Services` | `string[]` | `@()` | Filtra solo los servicios indicados. |
| `-DryRun` | `switch` | `false` | Lista las ramas `[gone]` sin borrarlas. |
| `-NoFetch` | `switch` | `false` | Omite `git fetch --all --prune` antes de inspeccionar. |
| `-OutFile` | `string` | `clean-branches-report.md` | Ruta del reporte Markdown de salida. |
| `-Console` | `switch` | `false` | Imprime resultados en consola en lugar de crear el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda de carpetas `.git`. |

## Ejemplos de uso manual

Simular qué ramas `[gone]` se borrarían sin tocar nada:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\clean-branches.ps1" -Path "D:\Projects\Go" -DryRun
```

Limpiar ramas `[gone]` ya mergeadas en todos los repos:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\clean-branches.ps1" -Path "D:\Projects\Go"
```

Limpiar solo en servicios específicos sin hacer fetch previo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-git\scripts\clean-branches.ps1" -Path "." -Services svc-1,svc-2 -NoFetch -Console
```

## Comandos Git equivalentes (manual)

Actualizar referencias y limpiar tracking remotos obsoletos:

```bash
git -C <repo> fetch --all --prune --quiet
```

Listar ramas locales con su estado de tracking:

```bash
git -C <repo> for-each-ref --format="%(refname:short)|%(upstream:track)" refs/heads/
```

Eliminar de forma segura una rama ya mergeada:

```bash
git -C <repo> branch -d <rama>
```
