# `fix-go-vulns.ps1`

Audita y opcionalmente remedia vulnerabilidades en múltiples servicios Go usando `govulncheck`. Por defecto opera en modo auditoría (`-Audit`) y genera un reporte Markdown (`go-vulns-report.md`).

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- `go` en el `PATH`
- `govulncheck` en el `PATH` o en `%GOPATH%\bin` (puede instalarse automáticamente con `-InstallTool`)

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz donde buscar módulos (`go.mod`). |
| `-Services` | `string[]` | `@()` | Filtra solo las carpetas/servicios indicados. |
| `-Audit` | `switch` | `false` | Fuerza modo solo auditoría (comportamiento base si no se pasan flags de cambio). |
| `-Fix` | `switch` | `false` | Actualiza de forma quirúrgica módulos de terceros con `fixed_version` (`go get <mod>@<ver>`). |
| `-FixStdlib` | `switch` | `false` | Sube `go@<fixed_version>` cuando `govulncheck` reporta vulnerabilidades en `stdlib`. |
| `-GoVersion` | `string` | `""` | Ejecuta `go mod tidy -go=<ver>` para fijar o subir la versión de Go en `go.mod`. |
| `-UpgradeAll` | `switch` | `false` | Ejecuta el flujo completo `go mod tidy` + `go get -u ./...` + `go mod tidy`. |
| `-InstallTool` | `switch` | `false` | Instala `govulncheck` automáticamente si no está disponible. |
| `-Race` | `switch` | `false` | Usa `go test -race ./...` en la verificación posterior. |
| `-SkipTests` | `switch` | `false` | Omite `go test` tras actualizar (solo corre `go vet ./...`). |
| `-OutFile` | `string` | `go-vulns-report.md` | Ruta del reporte Markdown de salida. |
| `-Console` | `switch` | `false` | Imprime el resumen en consola en lugar de escribir el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda de archivos `go.mod`. |

## Ejemplos de uso manual

Auditar todos los servicios Go (instalando `govulncheck` si falta):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\fix-go-vulns.ps1" -Path "D:\Projects\Go" -Audit -InstallTool
```

Remediación quirúrgica de dependencias + tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\fix-go-vulns.ps1" -Path "D:\Projects\Go" -Fix
```

Remediación incluyendo `stdlib`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\fix-go-vulns.ps1" -Path "D:\Projects\Go" -Fix -FixStdlib
```

Fijar versión de Go en `go.mod`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\fix-go-vulns.ps1" -Path "D:\Projects\Go" -GoVersion "1.27.1"
```

Flujo clásico de actualización general:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-dev-go\scripts\fix-go-vulns.ps1" -Path "D:\Projects\Go" -UpgradeAll
```

## Comandos Go equivalentes (manual)

Auditoría de vulnerabilidades:

```bash
govulncheck -format json ./...
```

Actualizar módulo vulnerable puntual (modo `-Fix`):

```bash
go get <modulo>@<fixed_version>
```

Actualizar versión de Go para `stdlib` (modo `-FixStdlib`):

```bash
go get go@<fixed_version>
```

Fijar versión de Go en `go.mod` (modo `-GoVersion`):

```bash
go mod tidy -go=<version>
```

Actualizar todas las dependencias (modo `-UpgradeAll`):

```bash
go get -u ./...
```

Limpiar `go.mod` y `go.sum`:

```bash
go mod tidy
```

Análisis estático:

```bash
go vet ./...
```

Ejecutar tests:

```bash
go test ./...
```

Ejecutar tests con detector de race conditions (`-Race`):

```bash
go test -race ./...
```

Re-verificar vulnerabilidades:

```bash
govulncheck ./...
```
