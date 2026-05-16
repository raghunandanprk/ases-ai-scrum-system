---
name: ases-test-run
description: >
  ASES Sprint Ship — Execute all written tests (unit, edge, integration) and capture results.
  Invoke with /ases-test-run [sprint-id] after /ases-test-impl. Runs regression check against
  all previous sprint tests first. Failed tests route to /ases-fix with max 3 iterations.
  Gate: all critical-priority tests must pass before proceeding.
allowed-tools: Read, Write, Bash(pytest:*), Bash(cd:*), Bash(python:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-test-run [sprint-id]`
**Agent:** Execution (Sonnet / configured alternative) · **Scope:** Sprint

Parse: `SPRINT_ID` = argument.

---

## Step 0 — Regression Check (all previous sprints)

Read `sprints/S*/ship/test_suite.json` for ALL sprints prior to `$SPRINT_ID`.

For each previous sprint's test suite:
```bash
pytest backend/tests/ -v --tb=short
```

If any previous test fails:
- Flag as `regression` with `severity: critical`
- Include in final report under `regressions[]`
- Regressions are **blocking** — must fix before proceeding

---

## Step 1 — Read Current Sprint Test Suite

Read `sprints/$SPRINT_ID/ship/test_suite.json`.

Extract `run_all_cmd` and per-file `run_cmd` entries.

---

## Step 2 — Execute Tests

Run the full test suite:
```bash
cd backend && pytest tests/ -v --tb=short --json-report --json-report-file=test_results.json
```

If `pytest-json-report` is not available, parse stdout for pass/fail per test function.

---

## Step 3 — Capture Results

For each test case in `test_suite.json`:
- Map test function name → `test_case_ref` via `coverage_map`
- Record `result: pass | fail | error`
- Capture error output for failures

Update `test_suite.json`:
- `status: written` → `passed` / `failed` / `error`
- Add `run_output` field with captured output

---

## Step 4 — Fix Loop (if failures)

If any test fails:

1. Map failing test → `task_ref` via `coverage_map` in `test_suite.json`
2. Identify the source file from `sprints/$SPRINT_ID/execution/tasks.json` → task → `output_files[]`
3. Route to `/ases-fix [task-id] $SPRINT_ID` for the source file
4. After fix → re-run ONLY the failing tests (not the full suite)
5. **Max 3 fix attempts** per failing test — then escalate to PO

### Fix iteration tracking
```json
{
  "test_ref": "TC-001",
  "task_ref": "T-001",
  "fix_attempts": 1,
  "max_attempts": 3,
  "status": "retrying"
}
```

---

## Step 5 — Gate Check

**Gate: ALL tests with `priority: critical` must have `status: passed`.**

- If gate passes → proceed to next step
- If gate fails after max fix attempts → ESCALATE to PO

---

## Output
```
sprints/$SPRINT_ID/ship/test_run_report.json
sprints/$SPRINT_ID/ship/test_run_report.md
sprints/$SPRINT_ID/ship/test_suite.json          ← updated with results
```

Report structure:
```json
{
  "sprint_id": "$SPRINT_ID",
  "executed_at": "<ISO-8601>",
  "total_tests": 0,
  "passed": 0,
  "failed": 0,
  "errors": 0,
  "regressions": [],
  "fix_attempts": [],
  "gate_verdict": "PASS | FAIL",
  "run_cmd": "pytest backend/tests/ -v"
}
```

## Next Step
Gate PASS → `/ases-integration-test $SPRINT_ID`
Gate FAIL → escalate to PO
