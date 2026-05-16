---
name: ases-test-impl
description: >
  ASES Sprint Ship — Claude Sonnet implements test specifications from test_cases.json as
  runnable code. Invoke with /ases-test-impl [sprint-id] after /ases-sprint-close. Implements
  ONLY specs from test_cases.json — zero invented cases. Strict naming convention and directory
  mapping enforced. Scoped to completed tasks only.
allowed-tools: Read, Write, Bash(find:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-test-impl [sprint-id]`
**Agent:** Developer (Claude Sonnet) · **Scope:** Sprint

---

## Step 1 — Read Inputs

```
sprints/$ARGUMENTS/design/test_cases.json       ← specs to implement
sprints/$ARGUMENTS/ship/sprint_summary.json     ← completed_tasks[] — scope filter
sprints/$ARGUMENTS/design/lld.json              ← function signatures
```

Filter: implement only test cases where `test_case.file_ref` maps to a completed task.
Skip deferred task tests — record `skip_reason: "task deferred to [sprint]"` in test_suite.json.

---

## Step 2 — Naming Convention (mandatory)

Every test function MUST follow this pattern:
```
test_{tc_id_lowercase}_{brief_description}
```

Examples:
- `TC-001` → `test_tc001_empty_input_returns_empty_array`
- `TC-007` → `test_tc007_invalid_bar_raises_value_error`

No other naming format is permitted.

---

## Step 3 — Directory Mapping (mandatory)

| `test_case.type` | Directory | Filename |
|---|---|---|
| `unit` | `backend/tests/unit/` | `test_{file_stem}.py` |
| `edge` | `backend/tests/unit/` | `test_{file_stem}_edge.py` |
| `integration` | `backend/tests/integration/` | `test_{module}.py` |
| `performance` | `backend/tests/system/` | `test_perf_{feature}.py` |
| `security` | `backend/tests/system/` | `test_security_{feature}.py` |

---

## Step 4 — Implementation Rules

- Use EXACT `inputs` and `expected_output` from test_cases.json — no approximations
- Use `framework` field from each test case — `pytest` or `jest`
- Tests MUST be deterministic — no `random`, no `datetime.now()`, no `uuid4()`
- No new test cases beyond what is in test_cases.json

---

## Step 5 — Write Test Suite Manifest

```
sprints/$ARGUMENTS/ship/test_suite.json
```

Structure per file:
```json
{
  "sprint_id": "$ARGUMENTS",
  "test_files": [
    {
      "path": "backend/tests/unit/test_signal.py",
      "task_ref": "T-001",
      "test_case_refs": ["TC-001", "TC-002"],
      "type": "unit",
      "framework": "pytest",
      "status": "written",
      "skip_reason": "",
      "run_cmd": "pytest backend/tests/unit/test_signal.py -v"
    }
  ],
  "coverage_map": {
    "TC-001": "backend/tests/unit/test_signal.py::test_tc001_empty_input_returns_empty_array"
  },
  "run_all_cmd": "pytest backend/tests/ -v",
  "total_cases": 0,
  "skipped_cases": 0
}
```

## Next Step
→ `/ases-test-run $ARGUMENTS`
