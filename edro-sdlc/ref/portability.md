# Repository Agnosticism & Portability Protocol

This reference establishes the strict portability and path-agnostic standards required across all projects developed with Edro.

---

## 1. Core Principle: Agnostic from Project Root Backwards

Every repository must be self-contained and path-agnostic from its project root backwards:

- **Prohibited**: Hardcoded absolute host paths, user home paths, or drive letters:
  - ❌ `D:/Projects/MyProject/...` <!-- portability-ignore -->
  - ❌ `C:\Users\username\...` <!-- portability-ignore -->
  - ❌ `/home/user/workspace/...` <!-- portability-ignore -->
  - ❌ `file:///D:/...` or `file:///Users/...` <!-- portability-ignore -->
- **Mandatory**: Relative paths, root-relative references, or runtime-resolved paths:
  - ✅ `./docs/spec.md`
  - ✅ `../../docs/spec_protocol.md`
  - ✅ PowerShell scripts resolving root via `$PSScriptRoot`
  - ✅ Bash scripts resolving root via `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`
  - ✅ Application code using `AppContext.BaseDirectory`, `os.Executable()`, OS appdata, or env/flags.

---

## 2. Scope of Enforcement

1. **Documentation & Context Tracking**:
   - `README.md`, `AGENTS.md`, and all files under `agents/` (`history.md`, `fases.md`, `specs/`).
   - Links between markdown files must use relative paths from the current file.
2. **Build & Automation Scripts**:
   - Derive repository root dynamically from script location rather than assuming a fixed directory.
   - Output artifacts to repo-relative directories (e.g., `dist/`, `bin/`).
3. **Source Code & Configuration**:
   - No hardcoded machine-specific directories.
   - Cache, DB, and binary paths must resolve relative to executable/workdir, user appdata, or config/env vars.

---

## 3. Automated Audit Scripts (Step 4 Gate)

Run the portability scanner from the target workspace root before closing any task:

- **Windows (PowerShell)**:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/audit-paths.ps1" -Root .
  ```
- **macOS / Linux (Bash)**:
  ```bash
  bash "<path-to-skill>/scripts/audit-paths.sh" .
  ```

### Interpreting & Fixing Results
- **Exit code `0`**: Clean; proceed to Step 5.
- **Exit code `1`**: One or more `file:line` violations were detected. Replace each hardcoded path with a relative or runtime-resolved path, then re-run until exit code `0`.
- **Intentional negative examples** (e.g., inside portability docs or unit tests asserting rejection of host paths): annotate the line with `portability-ignore`.
