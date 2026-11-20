# `detect-services.ps1`

Escanea las carpetas de un workspace y detecta el stack tecnológico principal de cada servicio/proyecto. Por defecto genera una tabla Markdown (`services-report.md`) para evitar ruido en consola.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+

## Parámetros

| Parámetro | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `-Path` | `string` | `.` | Ruta raíz del workspace a escanear. |
| `-OutFile` | `string` | `services-report.md` | Ruta del archivo Markdown de salida. |
| `-Console` | `switch` | `false` | Imprime `<servicio> - <stack>` en consola en lugar de crear el `.md`. |
| `-Depth` | `int` | `1` | Profundidad de búsqueda (`2` si los servicios están en subcarpetas como `services/api`). |

## Ejemplos de uso manual

Generar reporte Markdown en el directorio actual:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-workspace\scripts\detect-services.ps1" -Path "."
```

Escanear subcarpetas (`Depth 2`) sobre otro workspace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-workspace\scripts\detect-services.ps1" -Path "D:\Projects\Go" -Depth 2
```

Imprimir directo en consola sin generar archivo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\edro-workspace\scripts\detect-services.ps1" -Path "." -Console
```

## Cómo lo detecta (equivalente manual)

Inspecciona cada carpeta buscando archivos manifiesto:

- `go.mod` → `Go`
- `pom.xml`, `build.gradle`, `build.gradle.kts` → `Java`
- `package.json` → revisa `dependencies` y `devDependencies` para distinguir `Nuxt (Vue)`, `Vue`, `Next.js (React)`, `React`, `Angular`, `Svelte`, `NestJS` o `Node.js`
- `pyproject.toml`, `requirements.txt`, `Pipfile`, `setup.py` → `Python`
- `Cargo.toml` → `Rust`
- `*.csproj`, `*.sln` → `.NET`
- `composer.json` → `PHP`
- `Gemfile` → `Ruby`
