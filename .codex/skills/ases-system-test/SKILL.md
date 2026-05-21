---
name: ases-system-test
description: >
  ASES Sprint Ship — Design and execute end-to-end system tests against PRD non-functional
  requirements. Invoke with /ases-system-test [sprint-id] after /ases-integration-test.
  Opus designs NFR scenarios with numeric thresholds. Claude Sonnet executes them using
  explicit framework per test type. Writes exact result structure to system_test_report.json.
allowed-tools: Read, Write, Bash(pytest:*), Bash(python3:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-system-test [sprint-id]`
**Agent:** Tester (Opus designs · Claude Sonnet executes) · **Scope:** Sprint

---

## Step A — Opus Designs Scenarios

Read `contracts/prd.json` (non_functional), `contracts/hld.json` (risks[]),
`sprints/$ARGUMENTS/ship/sprint_summary.json`

For each critical NFR → write one scenario with a numeric threshold.
For each `severity: critical | medium` risk → write a scenario testing its mitigation.

Write `sprints/$ARGUMENTS/ship/system_test_scenarios.json`

---

## Step B — Sonnet Executes

**Pre-check:** Read `sprints/$ARGUMENTS/ship/system_test_scenarios.json`.
If missing → STOP → "system_test_scenarios.json missing — Opus must complete Step A."

**Framework per test type — mandatory:**

| `scenario.type` | Framework | How |
|---|---|---|
| `performance` | `pytest-benchmark` | `@pytest.mark.benchmark` fixture |
| `error_handling` | `pytest` | `pytest.raises(ExpectedError)` |
| `boundary` | `pytest` | `@pytest.mark.parametrize` with boundary values |
| `security` | `pytest` | Direct calls with malformed/injection inputs |
| `load` | `locust` or `pytest` | Simulate N concurrent requests |

**Execute each scenario. Record results in exact format:**

```json
{
  "id": "ST-001",
  "type": "performance",
  "nfr_ref": "non_functional.performance",
  "description": "",
  "threshold": "p95 < 100ms",
  "result": "pass | fail | skip",
  "actual_value": "87ms",
  "details": "",
  "severity_if_failed": "critical | major | minor"
}
```

**Write `sprints/$ARGUMENTS/ship/system_test_report.json`:**

```json
{
  "sprint_id": "$ARGUMENTS",
  "executed_at": "<ISO-8601>",
  "scenarios": [<array of scenario results above>],
  "verdict": "pass | fail",
  "critical_failures": ["ST-002"]
}
```

Write `sprints/$ARGUMENTS/ship/system_test_report.md` — human-readable summary.

## Next Step
→ `/ases-uat $ARGUMENTS`
