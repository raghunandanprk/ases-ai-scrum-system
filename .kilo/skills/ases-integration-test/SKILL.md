---
name: ases-integration-test
description: >
  ASES Sprint Ship — Design and implement cross-module integration tests. Invoke with
  /ases-integration-test [sprint-id] after /ases-test-impl. Opus designs scenarios from
  HLD data_flow. Claude Sonnet implements them. One file per scenario with strict naming.
  Only external services may be mocked — all src/ code called directly.
allowed-tools: Read, Write, Bash(pytest:*), Bash(find:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-integration-test [sprint-id]`
**Agent:** Tester (Opus designs · Claude Sonnet implements) · **Scope:** Sprint

---

## Step A — Opus Designs Scenarios

Read `contracts/hld.json` (data_flow[]), `sprints/$ARGUMENTS/design/lld.json`,
`sprints/$ARGUMENTS/ship/test_suite.json`

For each `data_flow` entry involving this sprint's modules:
- Define `entry_point`, `flow[]` steps, `exit_assertion`
- Specify `test_data` — concrete values, not "some valid input"
- Assign `priority: critical | high | low`

Write `sprints/$ARGUMENTS/ship/integration_scenarios.json`

---

## Step B — Sonnet Implements

**Pre-check:** Read `sprints/$ARGUMENTS/ship/integration_scenarios.json`.
If missing → STOP → "integration_scenarios.json missing — Opus must complete Step A first."

**File naming — mandatory:**
One test file per scenario:
```
backend/tests/integration/test_integration_{IS_id_lowercase}_{module_a}_to_{module_b}.py
```
Example: `test_integration_is001_data_loader_to_signal_generator.py`

**Function naming — mandatory:**
One test function per scenario file:
```python
def test_{IS_id_lowercase}():
```
Example: `def test_is001():`

**Mocking rules — positive statement:**
ONLY these may be mocked using `unittest.mock`:
- External HTTP calls (`requests.get`, `httpx.post`, etc.)
- Database connections (`psycopg2.connect`, `asyncpg.connect`, etc.)
- Third-party API clients
- File system I/O for external storage

Everything within `backend/src/` is called directly — no mocking of internal modules.

## Step C — Execute Integration Tests

**Run all integration tests:**
```bash
cd backend && pytest tests/integration/ -v --tb=short
```

**Capture results per scenario:**
```json
{
  "scenario_id": "IS-001",
  "result": "pass | fail | error",
  "output": "<captured output>"
}
```

**If any test fails:**
1. Identify the source module from the scenario's `flow[]` steps
2. Map to task via `sprints/$ARGUMENTS/execution/tasks.json`
3. Route to `/ases-fix [task-id] $ARGUMENTS` for the source file
4. After fix → re-run ONLY the failing integration test
5. **Max 3 fix attempts** — then escalate to PO

Append results to `integration_scenarios.json` under `execution_results[]`.

## Output
```
sprints/$ARGUMENTS/ship/integration_scenarios.json    ← updated with execution_results[]
backend/tests/integration/test_integration_*.py
```

## Next Step
All tests pass → `/ases-system-test $ARGUMENTS`
Fixes needed → fix loop (max 3) → re-run failing tests
