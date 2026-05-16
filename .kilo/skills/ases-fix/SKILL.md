---
name: ases-fix
description: >
  ASES Sprint Execution — Claude Sonnet applies critique fixes to task files. Invoke with
  /ases-fix [task-id] [sprint-id] after /ases-critique FIX_REQUIRED. FIRST reads task plan
  to extract permitted write scope, THEN reads critique, THEN applies fixes. Scope is
  strictly output_files[] from the original plan — nothing else. Escalates if fix needs
  out-of-scope file. Always triggers /ases-critique after every fix.
allowed-tools: Read, Write
argument-hint: "[task-id e.g. T-001] [sprint-id e.g. S1]"
---

# ASES `/ases-fix [task-id] [sprint-id]`
**Agent:** Developer (Claude Sonnet) · **Scope:** Task original files only

Parse: `TASK_ID` = first arg · `SPRINT_ID` = second arg

---

## Step 1 — Establish Write Scope FIRST

Read `sprints/$SPRINT_ID/execution/tasks/$TASK_ID-plan.json`
Extract `output_files[]` — this is your COMPLETE permitted write scope.
Write this list down. You may touch NO other file under any circumstance.

---

## Step 2 — Read Critique

Read `sprints/$SPRINT_ID/execution/critique_$TASK_ID.json`

Process only issues where `severity: "critical"` or `severity: "major"`.
Ignore `minor` issues unless they are directly related to a critical fix.

For each issue:
- Confirm `issue.file` is within `output_files[]`
- If NOT → do not proceed → write ESCALATE to output

---

## Step 3 — Check Scope Before Each Fix

Before applying any `fix_instruction`:
1. Confirm the target file is in `output_files[]`
2. If yes → apply exactly as instructed, no embellishment
3. If no → flag `ESCALATE` with reason "fix requires out-of-scope file: [filename]"

---

## Step 4 — Write Updated Snapshot

After applying all fixes, write:
```
sprints/$SPRINT_ID/execution/snapshots/$TASK_ID-fix-[N].json
```

Where N = current `task.iteration_count + 1`.

Exact structure:
```json
{
  "task_id": "$TASK_ID",
  "sprint_id": "$SPRINT_ID",
  "snapshot_type": "post_fix",
  "iteration": N,
  "timestamp": "<ISO-8601>",
  "files_modified": ["<actual files changed>"],
  "issues_addressed": ["I-001", "I-002"],
  "file_hashes": {}
}
```

---

## Step 5 — Update Iteration Count

Update `sprints/$SPRINT_ID/execution/tasks.json`:
Set task `iteration_count` = current value + 1.

---

## Rules
- Apply fixes EXACTLY as instructed — no additional "improvements" or refactoring
- Never touch files outside `output_files[]` — escalate instead
- No new imports, no new functions unless the `fix_instruction` explicitly requires them

## Next Step
Always → `/ases-critique $TASK_ID $SPRINT_ID`
