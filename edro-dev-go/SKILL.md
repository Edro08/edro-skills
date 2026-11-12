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

## Reference & Customization

- [ref/conventions.md](ref/conventions.md): Detailed conventions for project layout, error/logging patterns, testing, and Go tooling.
