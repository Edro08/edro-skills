# Architecture Specification — [ProjectName]

## 1. Overview
Concise summary of the project's purpose, runtime targets, and core constraints.

## 2. Directory & Package Boundaries
| Module / Path | Responsibility | Allowed Dependencies |
| :--- | :--- | :--- |
| `...` | `...` | `...` |

## 3. Dependency Direction & Composition Rules
- Describe strict dependency flow (e.g., `cmd/` -> `internal/app/` -> `internal/domain/`).
- Call out forbidden cross-imports or anti-patterns.

## 4. Portability & Environment Contracts
- Configuration sources (env vars, flags, relative config files).
- Storage/cache locations (resolved relative to executable, working dir, or OS appdata—never hardcoded host paths).
