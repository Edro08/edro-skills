# `test-go-repos.ps1`

Ejecuta `go vet ./...` y `go test ./...` (opcionalmente con `-race`) en múltiples servicios Go. Genera un reporte Markdown (`go-tests-report.md`) con el estado por servicio y el detalle de salida únicamente de los que fallaron.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- `go` en el `PATH`

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz donde buscar módulos (`go.mod`). |
| `-Services` | `string[]` | `@()` | Filtra solo los servicios indicados. |
| `-Race` | `switch` | `false` | Ejecuta `go test -race ./...` en lugar de `go test ./...`. |
| `-SkipVet` | `switch` | `false` | Omite `go vet ./...`. |
| `-OutFile` | `string` | `go-tests-report.md` | Ruta del reporte Markdown de salida. |
| `-Console` | `switch` | `false` | Imprime resultados en consola en lugar de crear el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda de archivos `go.mod`. |

## Ejemplos de uso manual

Ejecutar `go vet` y `go test` en todos los servicios Go:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\test-go-repos.ps1" -Path "D:\Projects\Go"
```

Ejecutar con detector de race conditions (`-race`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\test-go-repos.ps1" -Path "D:\Projects\Go" -Race
```

Ejecutar solo en servicios puntuales e imprimir en consola:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\test-go-repos.ps1" -Path "D:\Projects\Go" -Services go-archkit,go-utils -Console
```

## Comandos Go equivalentes (manual)

Análisis estático dentro de cada servicio:

```bash
go vet ./...
```

Ejecutar suite de tests:

```bash
go test ./...
```

Ejecutar suite de tests con detector de race conditions:

```bash
go test -race ./...
```
