# Security Audit Report — [ProjectName / Feature]

- **Date**: YYYY-MM-DD
- **Cycle**: Initial / Retry #1 / Retry #2
- **Scope Audited**: `agents/specs/architecture.md`, codebase, configs, dependencies

## 1. Automated Scans Executed
| Tool / Scan | Command | Result |
| :--- | :--- | :--- |
| Dependency / Vuln scan | `...` | Clean / Findings |
| Portability / Host-path audit | `audit-paths` | Exit 0 / Exit 1 |

## 2. Security & Hardening Checklist
- [ ] AuthN / AuthZ boundaries enforced (no IDOR / missing checks)
- [ ] Input validation & injection protection (SQLi, XSS, SSRF, Cmd, Path Traversal)
- [ ] No hardcoded secrets, tokens, or sensitive data in logs
- [ ] Hardening applied (headers, CORS, least privilege, safe error handling)

## 3. Findings *(if any)*
| ID | Severity | Location | Impact | Required Remediation |
| :--- | :--- | :--- | :--- | :--- |
| `SEC-01` | High | `...` | `...` | `...` |

## 4. Verdict
`STATUS: PASS` *(or `STATUS: FAIL`)*
