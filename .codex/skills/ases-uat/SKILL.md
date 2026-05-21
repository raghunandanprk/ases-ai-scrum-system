---
name: ases-uat
description: >
  ASES Sprint Ship — Product Owner reviews the running system against PRD acceptance criteria.
  Invoke with /ases-uat [sprint-id] after /ases-system-test. Generates uat_checklist.md for
  PO to work through. PO marks each AC item. Rejected items trigger surgical re-entry.
  APPROVED verdict unlocks /ases-devops. Human-only step.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-uat [sprint-id]`
**Agent:** PO (Human) · **Scope:** Sprint · **⚠ Human required**

## Setup
Generate `sprints/$ARGUMENTS/ship/uat_checklist.md` from PRD AC items for this sprint.

## Checklist Format Per Item
```
[ ] {AC-ID} ({Feature-ID}): {acceptance criterion}
    How to verify: {verification steps}
    System test result: {pass/fail from system_test_report}
```

## PO Reviews Running System
For each item: mark `accepted | accepted_with_notes | rejected`

## Verdicts
- **APPROVED** — all accepted or accepted_with_notes
- **CONDITIONAL** — same as APPROVED, notes logged as tech debt
- **REJECTED** — one or more items rejected

## Rejected Item Routing
| Root Cause | Re-entry Point |
|---|---|
| Dev code issue | `/ases-validate` → `/ases-dev` → `/ases-critique` → `/ases-fix` |
| Spec issue | `/ases-prd-update` next sprint |
| UI issue | `/ases-ui-design` → `/ases-ui-review` → `/ases-ui-scaffold` |

## Output
```
sprints/$ARGUMENTS/ship/uat_report.json      ← schema: format/json/uat_report.schema.json
sprints/$ARGUMENTS/ship/uat_report.md
sprints/$ARGUMENTS/ship/uat_checklist.md
```

APPROVED | CONDITIONAL → `/ases-devops $ARGUMENTS`
REJECTED → surgical re-entry at identified root cause
