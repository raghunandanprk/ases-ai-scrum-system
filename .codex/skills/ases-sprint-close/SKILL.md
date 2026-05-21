---
name: ases-sprint-close
description: >
  ASES Sprint Execution — Close the sprint after all tasks reach final status. Invoke with
  /ases-sprint-close [sprint-id] after all tasks are complete/deferred/escalated. Stamps
  context.json, updates decisions.json, produces sprint_summary, feeds Phase 3 and next sprint.
  Nothing from this sprint is lost.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-sprint-close [sprint-id]`
**Agent:** Planner (Opus) · **Scope:** Sprint

## Input
Read `sprints/$ARGUMENTS/execution/tasks.json` (final statuses),
`sprints/$ARGUMENTS/execution/critique_T-*.json` (tech debt sources),
`.ases/decisions.json`, `.ases/context.json`

## Step 0 — Refresh Knowledge Graph
Run `graphify update .` to capture final code state for Phase 3.
If context bracket is DEPLETED/CRITICAL, skip this step.

## Pre-Check — No Orphaned Tasks
Read `sprints/$ARGUMENTS/execution/tasks.json` — verify **NO** tasks have `status: in_progress`.

If any task is `in_progress` → **BLOCK** sprint-close:
- List each in_progress task with its `task_id` and `output_files[]`
- PO must resolve each:
  - **Complete it** → run dev→critique→fix loop
  - **Defer it** → mark deferred with reason
  - **Escalate it** → mark escalated

Only proceed when ALL tasks are `complete`, `deferred`, or `escalated`.

## Process
1. Classify all tasks: completed / deferred / escalated
2. Collect new architectural decisions made during sprint
3. Identify tech debt from deferred critique issues
4. Generate `next_sprint_inputs` — carry-forward, constraints, suggested PRD updates
5. Identify `test_case_refs_to_verify` for Phase 3
6. Stamp `context.json` sprint_history entry

## Rules
- Every deferred task must have a reason
- Every escalation resolved or explicitly carried forward
- `suggested_prd_updates` must be specific
- New decisions written to `decisions.json`
- Set `context.json current_phase` → `SPRINT_SHIP`

## Output
```
sprints/$ARGUMENTS/ship/sprint_summary.json   ← schema: format/json/sprint_summary.schema.json
sprints/$ARGUMENTS/ship/sprint_summary.md
.ases/context.json                             ← sprint_history updated
.ases/decisions.json                           ← updated
```

## Next Step
→ Phase 3 begins: `/ases-test-impl $ARGUMENTS`
