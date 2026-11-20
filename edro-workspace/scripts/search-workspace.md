# `search-workspace.ps1`

Busca un texto o expresión regular en múltiples servicios de un workspace (ignorando `.git`, `node_modules`, `vendor`, `target`, `dist`, `build`) y agrupa los resultados por servicio en un reporte Markdown (`search-report.md`). Usa `rg` (ripgrep) si está instalado o `Select-String` como respaldo.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- *(Opcional)* `rg` (ripgrep) en el `PATH` para mayor velocidad

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz del workspace. |
| `-Pattern` | `string` | *(obligatorio)* | Texto o regex a buscar. |
| `-Services` | `string[]` | `@()` | Filtra solo los servicios indicados. |
| `-Include` | `string` | `""` | Filtro de archivos (ej. `*.go`, `*.yml`). |
| `-Regex` | `switch` | `false` | Interpreta `-Pattern` como expresión regular en vez de texto literal. |
| `-CaseSensitive` | `switch` | `false` | Distingue mayúsculas y minúsculas. |
| `-MaxMatchesPerService` | `int` | `50` | Límite de líneas capturadas por servicio para mantener el reporte compacto. |
| `-OutFile` | `string` | `search-report.md` | Ruta del reporte Markdown de salida. |
| `-Console` | `switch` | `false` | Imprime solo el conteo por servicio en consola. |
| `-Depth` | `int` | `1` | Profundidad de carpetas de servicios. |

## Ejemplos de uso manual

Buscar un texto literal en todos los servicios y generar `search-report.md`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-workspace\scripts\search-workspace.ps1" -Path "D:\Projects\Go" -Pattern "slog"
```

Buscar solo en archivos `.go` usando expresión regular:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-workspace\scripts\search-workspace.ps1" -Path "D:\Projects\Go" -Pattern "http\.ListenAndServe" -Include "*.go" -Regex
```

Ver conteo rápido en consola sobre servicios puntuales:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-workspace\scripts\search-workspace.ps1" -Path "D:\Projects\Go" -Pattern "NewHealth" -Services go-archkit,go-template -Console
```

## Comandos equivalentes (manual)

Búsqueda rápida con `ripgrep` (si está instalado):

```bash
rg -n --fixed-strings --ignore-case --glob "!.git/**" --glob "!node_modules/**" --glob "!vendor/**" "<pattern>" .
```

Búsqueda nativa en PowerShell (`Select-String`):

```powershell
Get-ChildItem -Recurse -File | Select-String -SimpleMatch "<pattern>"
```
