---
name: ases-batch-dev
description: >
  ASES Sprint Execution — Standalone batch dev for all validated tasks in a single Sonnet
  session. Invoke with /ases-batch-dev [sprint-id] after /ases-batch-validate. Requires all
  target tasks to have validation_$TASK_ID.json with verdict PROCEED.
allowed-tools: Read, Write, Bash(find:*), Bash(ls:*), Bash(psql:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-batch-dev [sprint-id]`
**Agent:** Execution (Sonnet / configured alternative) · **Scope:** Sprint batch

Parse: `SPRINT_ID` = argument.

## Step 0 — Identify Validated Tasks

Read `sprints/$SPRINT_ID/execution/tasks.json`.

Eligible if:
1. `validation_$TASK_ID.json` exists with `verdict: PROCEED`
2. Task `status` is NOT `complete`, `deferred`, `escalated`, or `in_progress`

Group by `parallel_group[]`, process in topological order.

If zero eligible → "No validated tasks found — run /ases-batch-validate first" → STOP.

## Step 1 — Implement Each Task

For each validated task (same constraints as `/ases-dev`):

1. **Read instruction packet**: `$TASK_ID-plan.json`, `$TASK_ID-plan.md`, `lld.json`,
   `schema.json` (if DB task), `decisions.json` (relevant entries),
   `ui_scaffold_manifest.json` (if UI task)
2. **Extract and lock scope**: `output_files[]` is COMPLETE write scope
3. **Write pre-dev snapshot**: `snapshots/$TASK_ID-pre.json`
4. **Implement**: Follow plan.md exactly. Match lld signatures. No extras.
5. **Migration execution** (if `output_files[]` contains `*.sql`):
   `psql -U <db.app_role> -d <db.name> -f <migration_file>`
   If fails → stop this task, report, continue to next
6. **Update status**: `in_progress` in tasks.json
7. **Checkout**: `CHECKOUT: Changed [files]. Tests: [pending].`

## Rules
- Write ONLY to `output_files[]` — out-of-scope → ESCALATE
- No architectural decisions — implement plan + lld exactly
- UI tasks: only declared `integration_points[]`

## Output
Per task:
```
sprints/$SPRINT_ID/execution/snapshots/$TASK_ID-pre.json
Code written to output_files[]
tasks.json status → in_progress
```

## Next Step
→ `/ases-batch-critique $SPRINT_ID`
