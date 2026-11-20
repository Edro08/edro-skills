---
name: edro-dev-go
description: >-
  Edro's Go development conventions, package architecture, error handling,
  concurrency, and testing standards. Use when creating, refactoring, reviewing,
  or testing Go modules, CLI tools, MCP servers, or backend services.
---

# Edro Go Development Standards

Base skill defining idiomatic Go engineering practices for projects developed with Edro. Customize the placeholders in [ref/conventions.md](ref/conventions.md) with your preferred stack choices.

---

## Core Go Pillars

1. **Idiomatic & Simple Go**: Prefer standard library solutions (`net/http`, `database/sql`, `slog`, `errors`, `context`) over heavy frameworks or unnecessary wrappers.
2. **Explicit Error Handling**: Never ignore errors silently; wrap errors with context (`fmt.Errorf("...: %w", err)`) and keep error messages lowercase without trailing punctuation.
3. **Context & Resource Lifecycle**: Propagate `context.Context` as the first parameter on I/O, DB, and network calls; always defer `Close()` / cancel timers/contexts cleanly.
4. **Clean Package Boundaries**: Avoid circular dependencies and `utils`/`common` dumping grounds; keep `cmd/` thin and domain logic testable without transport coupling.
5. **Path-Agnostic & Portable**: Never hardcode host paths; resolve runtime paths from `os.Executable()`, flags, env vars, or working directory.

---

## Pre-Delivery Go Verification Gate

Before marking a Go task complete (or handing off to QA in `edro-sdlc`):

```bash
go vet ./...
go test -race ./...
```

*(Optionally run `golangci-lint run` and `govulncheck ./...` when configured in the project.)*

---

## Bulk Go Vulnerability Audit & Remediation

When the user asks to scan or fix Go vulnerabilities across multiple services/repositories:

1. Run the bundled PowerShell script (defaults to `-Audit` mode and writes `go-vulns-report.md` to minimize token usage):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-this-skill>/scripts/fix-go-vulns.ps1" -Path "." -Audit
   ```
2. Add `-Fix` to automatically upgrade vulnerable third-party dependencies with a `fixed_version` (`go get` + `go mod tidy`), run `go vet` / `go test`, and re-scan:
   - `-FixStdlib`: also upgrade `go@<fixed_version>` when `govulncheck` reports `stdlib` vulnerabilities.
   - `-GoVersion <ver>`: run `go mod tidy -go=<ver>` across matching repos to pin/bump the Go directive.
   - `-UpgradeAll`: run `go mod tidy` + `go get -u ./...` + `go mod tidy` instead of surgical dependency upgrades.
   - `-Services svc-1,svc-2`: target specific Go service folders.
   - `-InstallTool`: auto-install `govulncheck` if not present.
   - `-Race` / `-SkipTests`: control test verification after upgrading.
   - `-OutFile <path.md>` / `-Console`: customize report output.
3. Never auto-commit or push changes; follow `edro-git` for branch and commit confirmation.

---

## Bulk Go Verification (`go vet` + `go test`)

When the user asks to run `go vet` and `go test` across multiple Go services:

1. Run the bundled PowerShell script (writes `go-tests-report.md` with summary table and failure details only for failed services):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-this-skill>/scripts/test-go-repos.ps1" -Path "."
   ```
2. Optional flags: `-Race` (`go test -race ./...`), `-SkipVet`, `-Services svc-1,svc-2`, `-OutFile <path.md>`, `-Console`, `-Depth 2`.

---

## Reference & Customization

- [ref/conventions.md](ref/conventions.md): Detailed conventions for project layout, error/logging patterns, testing, and Go tooling.
