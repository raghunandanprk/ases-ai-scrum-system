---
name: ases-dev
description: >
  ASES Sprint Execution — Claude Sonnet implements exactly one task from the task plan.
  Invoke with /ases-dev [task-id] [sprint-id] after /ases-validate PROCEED. Reads explicit
  instruction packet — plan, lld, schema (if persistence task), decisions, ui_manifest (if ui task).
  Writes ONLY to output_files[] declared in the task plan. No inference, no assumptions.
allowed-tools: Read, Write, Bash(find:*), Bash(ls:*), Bash(psql:*)
argument-hint: "[task-id e.g. T-001] [sprint-id e.g. S1]"
---

# ASES `/ases-dev [task-id] [sprint-id]`
**Agent:** Developer (Claude Sonnet) · **Scope:** Task (single file set only)

Parse: `TASK_ID` = first arg · `SPRINT_ID` = second arg

---

## Step 1 — Read Instruction Packet (ALL reads happen before ANY writes)

Read these files in order:

```
sprints/$SPRINT_ID/execution/tasks/$TASK_ID-plan.json   ← primary instruction
sprints/$SPRINT_ID/execution/tasks/$TASK_ID-plan.md     ← pseudo-code + logic steps
sprints/$SPRINT_ID/design/lld.json                      ← interface contracts
```

If `task.file` path contains `models/`, `db/`, `repository/`, or `task.type == "db"`:
```
sprints/$SPRINT_ID/design/schema.json                   ← relevant entities only
```

Read `.ases/decisions.json` ONLY entries where `module_refs` intersects `task.module_ref`.

If `task.type == "ui"`:
```
sprints/$SPRINT_ID/execution/ui_scaffold_manifest.json  ← integration_points ONLY
```

---

## Step 2 — Extract and Lock Scope

From `$TASK_ID-plan.json`, extract:
```json
"output_files": ["src/engine/signal.py"]
```

**This list is your COMPLETE write scope. You may write to NO other files.**
If you believe a fix requires a file not in `output_files[]` → stop and flag ESCALATE.

---

## Step 3 — Write Pre-Dev Snapshot

Before writing any code, write:
```
sprints/$SPRINT_ID/execution/snapshots/$TASK_ID-pre.json
```

Exact structure:
```json
{
  "task_id": "$TASK_ID",
  "sprint_id": "$SPRINT_ID",
  "snapshot_type": "pre_dev",
  "timestamp": "<ISO-8601>",
  "files_in_scope": ["<from output_files[]>"],
  "file_hashes": {}
}
```

---

## Step 4 — Implement

Follow `$TASK_ID-plan.md` pseudo-code and logic steps exactly.
Match every function signature in `lld.json` exactly — name, inputs, outputs.
Do not add functions not in the lld entry. Do not create helper files.

**UI tasks only:** Write ONLY at locations declared in `integration_points[]`.
Structure, styling, component layout → untouched.

---

## Step 4.5 — Apply Migration (DB tasks only)

If `output_files[]` contains any `*.sql` migration file in `backend/db/migrations/`:
1. After writing the migration DDL, execute it:
   ```bash
   psql -U <db.app_role> -d <db.name> -f <migration_file>
   ```
2. If execution fails → STOP, report error (do not proceed to checkout)
3. Record in pre-dev snapshot: `migration_applied: true/false`

---

## Step 5 — Checkout Summary (required output)

When implementation is complete, output this exact format:
```
CHECKOUT: Changed [exact file list]. Tests: [test command or "pending"].
```

---

## Output
Code written to `output_files[]` only.
Snapshot at `sprints/$SPRINT_ID/execution/snapshots/$TASK_ID-pre.json`
Update `sprints/$SPRINT_ID/execution/tasks.json` task status → `in_progress`

## Next Step
→ `/ases-critique $TASK_ID $SPRINT_ID`
