---
name: ases-batch-exec
description: >
  ASES Sprint Execution — Orchestrates per-task sub-agent dispatch for validate + dev.
  Invoke with /ases-batch-exec [sprint-id] after /ases-tasks. Identifies all eligible tasks,
  groups by dependency order, and dispatches a worker-dev sub-agent for each task. Each worker
  runs in an isolated context — reads only its own plan, LLD slice, and schema slice. Orchestrator
  collects results, handles failures, and writes batch summary.
allowed-tools: Read, Write, Bash(find:*), Bash(ls:*), Agent(worker-dev)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-batch-exec [sprint-id]`
**Agent:** Orchestrator (Execution) · **Scope:** Sprint batch · **Pattern:** Per-task sub-agent dispatch

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

## Step 1 — Dispatch Per-Task Workers

For each dependency group (process groups in topological order):

### Per Task in Group

Dispatch sub-agent `worker-dev` with message:

```
Implement task $TASK_ID for sprint $SPRINT_ID.
Read your plan from sprints/$SPRINT_ID/execution/tasks/$TASK_ID-plan.json
Follow the standard ASES worker-dev process.
```

**Platform dispatch:**
- Claude Code: use the `Agent` tool → agent: `worker-dev`
- Kilo Code: use the `new_task` tool → mode: `worker-dev`

Each worker operates in an isolated context window. It reads only its own task's plan, LLD slice, schema slice, and decisions slice. It validates, implements, writes output files, and returns a result.

### Dependency Handling

- Tasks in the same `parallel_group[]` MAY be dispatched concurrently (where platform supports it)
- Tasks in subsequent groups MUST wait for all prior groups to complete
- Workers in a later group may read code written by workers in earlier groups (it exists on disk)

### Worker Results

Each worker returns exactly one of:
- `CHECKOUT: Changed [files]. Tests: [pending].` → task succeeded
- `HOLD: [reason]` → validation failed, task skipped
- `ESCALATE: [reason]` → ambiguity or scope issue
- `ERROR: [details]` → implementation or migration failure

### Failure Handling

- Worker timeout or error → retry ONCE with the same message
- Second failure → mark task as `ESCALATE`, continue remaining tasks
- HOLD tasks → record `hold_reason`, continue remaining tasks

---

## Step 2 — Collect and Finalize

After all workers in all groups complete:

1. **Verify output files** — for each successful worker, confirm its expected output files exist on disk
2. **Collect summaries** — gather all CHECKOUT / HOLD / ESCALATE / ERROR results
3. **Update tasks.json** — set status for each task based on worker result:
   - CHECKOUT → `in_progress`
   - HOLD → `pending` (unchanged)
   - ESCALATE → `escalated`
   - ERROR → `escalated`
4. **Write batch summary:**

```
BATCH COMPLETE: [N] validated+implemented, [H] HOLD, [E] ESCALATE, [R] ERROR
HOLD tasks: [list with hold_reasons]
ESCALATE tasks: [list with reasons]
ERROR tasks: [list with details]
```

---

## Step 3 — Update Knowledge Graph

Run `graphify update .` to refresh the graph with newly implemented code.
If context bracket is DEPLETED/CRITICAL, skip this step.

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
→ `/ases-batch-critique $SPRINT_ID`
