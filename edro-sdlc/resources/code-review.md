# Code & Architecture Review — [ProjectName / Feature]

- **Date**: YYYY-MM-DD
- **Active Branch**: `<branch-name>`
- **Autonomous Review Cycle (`review_retry_count`)**: `0 / 2` *(resets to `0` on each `Gate 3` consultant request)*
- **Scope Reviewed**: `agents/specs/architecture.md`, `agents/specs/design.md`, `agents/specs/prd.md`, `agents/context/fases.md`, diff

## 1. Tech Lead Autonomous Review (`Step 5.1`)
- [ ] **Architecture & Boundaries**: Matches `architecture.md` and package dependency rules.
- [ ] **Code Standards**: Follows stack conventions (e.g., `edro-dev-*`), clean error handling, unit tests passing.
- [ ] **Portability**: `audit-paths` exits with `0` (zero hardcoded host paths).
- [ ] **Spec Sync**: Zero drift against `prd.md` and `design.md`.

### Autonomous Review Findings *(if any)*
1. **[CR-01] Title**
   - **Location**: `path/to/file`
   - **Required Fix**: ...
   - **Resolution**: Pending / Fixed by `dev`

---

## 2. Gate 3 — Tech Lead Consultant Iterations (`Step 5.2`, `N` rounds)
> Record every change, fix, or refactor requested by the human Tech Lead Consultant during `Gate 3`. Each new consultant request resets `review_retry_count = 0`.

### Iteration #1 *(if applicable)*
- **Consultant Request**: ...
- **Action Taken by `dev` / `tech-lead`**: ...
- **Verification**: ...

---

## 3. Consolidation & Final Sign-off
- **Approved at `Gate 3`**: Pending / Yes (`YYYY-MM-DD`)
- **Consolidated into `architecture.md` & `fases.md`**: Pending / Done
- **Verdict**:
`STATUS: PASS` *(or `STATUS: FAIL` / `STATUS: IN_PROGRESS`)*
