---
name: ases-batch-critique
description: >
  ASES Sprint Execution — Batch critique for all dev'd tasks in a single Opus session.
  Invoke with /ases-batch-critique [sprint-id] after /ases-batch-exec or /ases-batch-dev.
  Runs the full 4-lens critique on each in_progress task. CLEAN tasks marked complete.
  FIX_REQUIRED tasks routed to per-task /ases-fix re-entry.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-batch-critique [sprint-id]`
**Agent:** Reasoning (Opus / configured alternative) · **Scope:** Sprint batch · **Max iterations:** 3–5 (smart cap)

Parse: `SPRINT_ID` = argument.

## Step 0 — Identify Dev'd Tasks

Read `sprints/$SPRINT_ID/execution/tasks.json`.

Eligible if:
- Task `status` is `in_progress`
- Corresponding code files in `output_files[]` exist (dev completed)

## Step 1 — Critique Each Task

For each eligible task, apply the same four lenses as `/ases-critique`:

### 1 — Spec
Does implementation match `plan.json`? Match lld function signatures + interfaces?

### 2 — Contract
Do exports match what other files expect (lld interfaces)?
Are all imports from `depends_on[]` used correctly?

### 3 — Test
Does implementation satisfy `test_case.expected_output`?
Are edge cases from `test_cases.json` handled?

### 4 — Security
Input validation, injection vectors, exposed secrets?

### 5 — Structural (if `graphify-out/graph.json` exists)
Call graph connectivity, orphan detection, dead imports.
Run `graphify query` once for the batch — not per-task.
Skip if context bracket is DEPLETED/CRITICAL.

## Rules
- Read `decisions.json` FIRST — set `is_adr_tradeoff: true` for known decisions
- Detection only — no rewrites
- `fix_instruction` must be specific + actionable

## Verdicts (per task)

- **CLEAN** → update `tasks.json` status → `complete` → update `context.json`
- **FIX_REQUIRED** → write critique JSON → route to per-task `/ases-fix $TASK_ID $SPRINT_ID`
- **ESCALATE** → see smart cap rules below

## Smart Iteration Cap
```
iteration ≥ 3 AND FIX_REQUIRED AND issues_remaining ≥ previous_issues → ESCALATE
iteration ≥ 5 → ESCALATE (hard cap regardless of progress)
```

## ESCALATE Handling
Present to PO with structured options:
1. **Accept with tech debt** → mark complete, log TD entry in decisions.json
2. **Rollback** → `/ases-rollback $TASK_ID $SPRINT_ID` → task returns to pending
3. **Simplify** → PO edits plan.md, reset iteration_count → re-run `/ases-dev`
4. **Defer** → mark deferred, create CF entry in global_context.json
5. **PRD issue** → `/ases-prd-update` next sprint

## Output
Per task:
```
sprints/$SPRINT_ID/execution/critique_$TASK_ID.json   ← schema: format/json/critique.schema.json
sprints/$SPRINT_ID/execution/critique_$TASK_ID.md
```

Batch summary:
```
BATCH CRITIQUE: [C] CLEAN, [F] FIX_REQUIRED, [E] ESCALATE
CLEAN: [list] → marked complete
FIX_REQUIRED: [list] → route to /ases-fix per task
ESCALATE: [list] → PO decision required
```

## Next Step
All CLEAN → `/ases-sprint-close $SPRINT_ID`
FIX_REQUIRED → per-task `/ases-fix $TASK_ID $SPRINT_ID` → `/ases-critique $TASK_ID $SPRINT_ID`
