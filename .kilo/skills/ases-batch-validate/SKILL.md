---
name: ases-batch-validate
description: >
  ASES Sprint Execution — Standalone batch validate for all eligible tasks in a single
  Sonnet session. Invoke with /ases-batch-validate [sprint-id] when you want validation
  only without dev. Useful for pre-flight checks before a targeted /ases-batch-dev.
allowed-tools: Read, Write, Bash(find:*), Bash(ls:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-batch-validate [sprint-id]`
**Agent:** Execution (Sonnet / configured alternative) · **Scope:** Sprint batch

Parse: `SPRINT_ID` = argument.

## Step 0 — Identify Eligible Tasks

Read `sprints/$SPRINT_ID/execution/tasks.json`.

Eligible if:
1. All `depends_on[]` tasks have `status: complete`
2. Task `status` is NOT `complete`, `deferred`, `escalated`, or `in_progress`
3. No existing `validation_$TASK_ID.json` with `verdict: PROCEED`

Group by `parallel_group[]`, process in topological order.

## Step 1 — Validate Each Task

For each eligible task, run four checks:
1. `input_files_exist` — all files in `task.inputs.reads_from[]` exist
2. `interface_contract_intact` — lld interface for this file not drifted
3. `scope_boundary_clear` — task files don't overlap with in-progress tasks
4. `no_circular_dependency` — all `depends_on[]` tasks are `status: complete`

## Rules
- Pre-flight only — no code review
- HOLD must include `hold_reason` + `suggested_resolution`
- Never block the entire batch — record HOLDs, continue validating

## Output
Per task:
```
sprints/$SPRINT_ID/execution/validation_$TASK_ID.json   ← schema: format/json/validation.schema.json
```

Batch summary:
```
BATCH VALIDATE: [N] PROCEED, [H] HOLD
HOLD tasks: [list with hold_reasons + suggested_resolutions]
```

## Next Step
→ `/ases-batch-dev $SPRINT_ID` or `/ases-batch-exec $SPRINT_ID` (combined)
