---
name: ases-batch-critique
description: >
  ASES Sprint Execution — Orchestrates per-task sub-agent dispatch for critique.
  Invoke with /ases-batch-critique [sprint-id] after /ases-batch-exec or /ases-batch-dev.
  Identifies all in_progress tasks and dispatches a worker-critic sub-agent for each. Each
  worker runs in an isolated context — reads only its task's code, plan, and LLD slice. Applies
  5 critique lenses. Orchestrator collects verdicts and handles smart iteration cap.
allowed-tools: Read, Write, Agent(worker-critic)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-batch-critique [sprint-id]`
**Agent:** Orchestrator (Reasoning) · **Scope:** Sprint batch · **Pattern:** Per-task sub-agent dispatch · **Max iterations:** 3–5 (smart cap)

Parse: `SPRINT_ID` = argument.

---

## Step 0 — Identify Dev'd Tasks

Read `sprints/$SPRINT_ID/execution/tasks.json`.

Eligible if:
- Task `status` is `in_progress`
- Corresponding code files in `output_files[]` exist (dev completed)

If zero eligible tasks → report "No tasks to critique" → STOP.

---

## Step 1 — Dispatch Per-Task Critics

For each eligible task, dispatch sub-agent `worker-critic` with message:

```
Critique task $TASK_ID for sprint $SPRINT_ID.
Read the implementation from the task's output_files[].
Follow the standard ASES worker-critic process.
```

**Platform dispatch:**
- Claude Code: use the `Agent` tool → agent: `worker-critic`
- Kilo Code: use the `new_task` tool → mode: `worker-critic`
- Codex: use the `runSubagent` tool → agent: `worker-critic`

Each worker operates in an isolated context window. It reads the task's code, plan, LLD slice, decisions slice, and test cases. It applies all 5 critique lenses and writes critique JSON+MD.

### Worker Results

Each worker returns exactly one of:
- `VERDICT: CLEAN — [summary]` → no issues found
- `VERDICT: FIX_REQUIRED — [N] issues` → critique written, fix needed
- `VERDICT: ESCALATE — [reason]` → iteration cap or stalling

---

## Step 2 — Collect Verdicts and Update State

After all workers complete:

### Per Task

- **CLEAN** → update `tasks.json` status → `complete` → update `.ases/context.json`
- **FIX_REQUIRED** → critique files written by worker → route to per-task `/ases-fix $TASK_ID $SPRINT_ID`
- **ESCALATE** → present to PO with structured options (see below)

### Smart Iteration Cap (tracked by orchestrator)

The orchestrator tracks iteration count across critique cycles. These rules apply when `/ases-batch-critique` is re-run after `/ases-fix`:

```
iteration ≥ 3 AND FIX_REQUIRED AND issues_remaining ≥ previous_issues → ESCALATE
iteration ≥ 5 → ESCALATE (hard cap regardless of progress)
```

### ESCALATE Handling

Present to PO with structured options:
1. **Accept with tech debt** → mark complete, log TD entry in decisions.json
2. **Rollback** → `/ases-rollback $TASK_ID $SPRINT_ID` → task returns to pending
3. **Simplify** → PO edits plan.md, reset iteration_count → re-run `/ases-dev`
4. **Defer** → mark deferred, create CF entry in global_context.json
5. **PRD issue** → `/ases-prd-update` next sprint

---

## Step 3 — Write Batch Summary

```
BATCH CRITIQUE: [C] CLEAN, [F] FIX_REQUIRED, [E] ESCALATE
CLEAN: [list] → marked complete
FIX_REQUIRED: [list] → route to /ases-fix per task
ESCALATE: [list] → PO decision required
```

---

## Model Resolution

Worker models are determined by each agent definition's `model:` field, which MUST match
the platform's `system.yaml` model configuration for the corresponding role:

| Worker | Role | system.yaml key |
|---|---|---|
| `worker-dev` | execution | `models.execution.primary` |
| `worker-critic` | reasoning | `models.reasoning.primary` |

The orchestrator MUST NOT hardcode model names in dispatch messages. The platform routes
workers to the correct model automatically via the agent's `model:` frontmatter.

If `system.yaml` models change, update the corresponding agent `model:` fields to match.

## Next Step
All CLEAN → `/ases-sprint-close $SPRINT_ID`
FIX_REQUIRED → per-task `/ases-fix $TASK_ID $SPRINT_ID` → `/ases-critique $TASK_ID $SPRINT_ID`
