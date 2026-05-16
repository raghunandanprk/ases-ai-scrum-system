---
name: ases-batch-exec
description: >
  ASES Sprint Execution — Combined batch validate + dev in a single Sonnet session.
  Invoke with /ases-batch-exec [sprint-id] after /ases-tasks. Identifies all tasks whose
  dependencies are satisfied and that are not already complete/deferred/escalated, validates
  them, then implements them — all in one context window. Enforces all constraints from
  /ases-validate and /ases-dev. Falls back to per-task mode for fix re-entry.
allowed-tools: Read, Write, Bash(find:*), Bash(ls:*), Bash(psql:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-batch-exec [sprint-id]`
**Agent:** Execution (Sonnet / configured alternative) · **Scope:** Sprint batch

Parse: `SPRINT_ID` = argument.

---

## Step 0 — Identify Eligible Tasks

Read `sprints/$SPRINT_ID/execution/tasks.json`.

For each task, check eligibility:
1. All `depends_on[]` tasks have `status: complete`
2. Task `status` is NOT `complete`, `deferred`, `escalated`, or `in_progress`
3. No existing `validation_$TASK_ID.json` with `verdict: PROCEED` (not already validated)

Group eligible tasks by `parallel_group[]`. Process groups in topological order.

If zero eligible tasks → report "No eligible tasks" → STOP.

---

## Phase 1 — Batch Validate

For EACH eligible task in the current batch, run ALL four validation checks
(same constraints as `/ases-validate`):

### Four Checks (per task)
1. `input_files_exist` — all files in `task.inputs.reads_from[]` exist
2. `interface_contract_intact` — lld interface for this file not drifted
3. `scope_boundary_clear` — task files don't overlap with in-progress tasks
4. `no_circular_dependency` — all `depends_on[]` tasks are `status: complete`

### Output (per task)
Write `sprints/$SPRINT_ID/execution/validation_$TASK_ID.json`

### HOLD Handling
If any task gets HOLD:
- Record the HOLD with `hold_reason` + `suggested_resolution`
- **Skip that task in Phase 2** — do not stop the entire batch
- Continue validating remaining tasks
- Report all HOLDs at end of Phase 1

---

## Phase 2 — Batch Dev

For EACH task that received `verdict: PROCEED` in Phase 1, implement it
(same constraints as `/ases-dev`):

### Per-Task Implementation
1. **Read instruction packet**: `$TASK_ID-plan.json`, `$TASK_ID-plan.md`, `lld.json`,
   `schema.json` (if DB task), `decisions.json` (relevant entries),
   `ui_scaffold_manifest.json` (if UI task)
2. **Extract and lock scope**: `output_files[]` is COMPLETE write scope — no other files
3. **Write pre-dev snapshot**: `snapshots/$TASK_ID-pre.json`
4. **Implement**: Follow plan.md pseudo-code exactly. Match lld signatures. No extras.
5. **Migration execution** (if `output_files[]` contains `*.sql`):
   Execute: `psql -U <db.app_role> -d <db.name> -f <migration_file>`
   If fails → stop this task, report error, continue to next task
6. **Update task status**: `in_progress` in tasks.json
7. **Checkout summary**: `CHECKOUT: Changed [files]. Tests: [pending].`

### Rules (enforced per task, same as /ases-dev)
- Write ONLY to `output_files[]` — if fix needs out-of-scope file → ESCALATE
- No architectural decisions — implement exactly what plan + lld specify
- No assumptions — if ambiguous, flag ESCALATE
- UI tasks: only declared `integration_points[]` — never touch scaffold structure

---

## Output

Per task:
```
sprints/$SPRINT_ID/execution/validation_$TASK_ID.json
sprints/$SPRINT_ID/execution/snapshots/$TASK_ID-pre.json
Code written to output_files[]
tasks.json status updated
```

Batch summary at end:
```
BATCH COMPLETE: [N] validated, [M] implemented, [H] HOLD, [E] ESCALATE
HOLD tasks: [list with hold_reasons]
ESCALATE tasks: [list with reasons]
```

## Step 3 — Update Knowledge Graph
Run `graphify update .` to refresh the graph with newly implemented code.
If context bracket is DEPLETED/CRITICAL, skip this step.

## Next Step
→ `/ases-batch-critique $SPRINT_ID`
