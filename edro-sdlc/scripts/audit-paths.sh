#!/usr/bin/env bash
# Audits a repository for hardcoded host paths or non-portable file:// URIs.
# Usage: ./audit-paths.sh [target_root]

set -euo pipefail

ROOT_DIR="${1:-.}"

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Error: Target root directory does not exist: $ROOT_DIR" >&2
  exit 2
fi

RESOLVED_ROOT="$(cd "$ROOT_DIR" && pwd)"

PATTERN='([A-Za-z]:[/\\]+(Users|Projects|home|Documents|Desktop|Downloads|OneDrive|Repos|Workspace|dev)\b|file:///[A-Za-z]:|file:///(home|Users)/|(^|[^A-Za-z0-9_])/(home|Users)/[A-Za-z0-9_.-]+/)'

if command -v rg >/dev/null 2>&1; then
  MATCHES="$(
    cd "$RESOLVED_ROOT" && rg -n --hidden --no-heading --ignore-case \
      --glob '!.git/**' \
      --glob '!node_modules/**' \
      --glob '!dist/**' \
      --glob '!bin/**' \
      --glob '!obj/**' \
      --glob '!build/**' \
      --glob '!target/**' \
      --glob '!.gradle/**' \
      --glob '!.idea/**' \
      --glob '!.vs/**' \
      --glob '!.venv/**' \
      --glob '!venv/**' \
      --glob '!__pycache__/**' \
      --glob '!vendor/**' \
      --glob '!coverage/**' \
      -e "$PATTERN" . | grep -v 'portability-ignore' || true
  )"
else
  MATCHES="$(
    cd "$RESOLVED_ROOT" && grep -rnIE \
      --exclude-dir=.git \
      --exclude-dir=node_modules \
      --exclude-dir=dist \
      --exclude-dir=bin \
      --exclude-dir=obj \
      --exclude-dir=build \
      --exclude-dir=target \
      --exclude-dir=.gradle \
      --exclude-dir=.idea \
      --exclude-dir=.vs \
      --exclude-dir=.venv \
      --exclude-dir=venv \
      --exclude-dir=__pycache__ \
      --exclude-dir=vendor \
      --exclude-dir=coverage \
      "$PATTERN" . | grep -v 'portability-ignore' || true
  )"
fi

if [[ -n "$MATCHES" ]]; then
  echo "FAIL: Potential non-portable path(s) detected:" >&2
  echo "$MATCHES" >&2
  exit 1
fi

echo "PASS: No hardcoded host paths detected under '$RESOLVED_ROOT'."
exit 0
