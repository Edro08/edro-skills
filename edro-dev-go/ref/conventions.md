# Go Conventions & Project Patterns (Base)

Customize each section below with Edro's specific Go preferences (frameworks, linters, logging library, DB drivers, etc.).

---

## 1. Project Layout
- `cmd/<app>/main.go`: Thin entrypoint (flag/env parsing, dependency wiring, graceful shutdown).
- `internal/...`: Private application/domain packages (prevent unintended external imports).
- `pkg/...` *(optional)*: Only when intentionally exposing reusable public libraries.
- **[TODO / Personalizar]**: *Define preferred layering (e.g., `handler -> service -> repository` or hexagonal/clean).*

## 2. Error Handling & Logging
- Wrap returned errors at boundary crossings: `fmt.Errorf("operation description: %w", err)`.
- Use `errors.Is` / `errors.As` for sentinel or typed error inspection.
- Use structured logging (`log/slog` by default unless project specifies otherwise); never log secrets or credentials.
- **[TODO / Personalizar]**: *Add custom error types, HTTP/MCP error mapping, or logger setup rules.*

## 3. Concurrency & Context
- Pass `ctx context.Context` as the first argument of functions doing I/O, DB queries, or HTTP calls.
- Respect `ctx.Done()` in loops and workers; bound goroutine lifetimes (`errgroup` / `sync.WaitGroup`).
- **[TODO / Personalizar]**: *Add worker pool, timeout defaults, or graceful shutdown standards.*

## 4. Testing & Tooling
- Prefer table-driven tests (`t.Run(...)`) with clear case names.
- Keep unit tests fast and deterministic; gate real DB/external integration tests behind build tags or explicit env flags if needed.
- Minimum checks before completion:
  ```bash
  gofmt -l .
  go vet ./...
  go test -race ./...
  ```
- **[TODO / Personalizar]**: *Add preferred assertion style (`stdlib` vs `testify`), mock strategy, or `golangci-lint` config.*
