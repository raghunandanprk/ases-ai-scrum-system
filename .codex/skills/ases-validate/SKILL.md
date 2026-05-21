---
name: ases-validate
description: >
  ASES Sprint Execution — Pre-flight check before every /ases-dev call. Invoke with
  /ases-validate [task-id] [sprint-id] before every task. Confirms input files exist,
  interface contracts intact, scope clear. HOLD blocks dev — cheaper to catch here.
  Every HOLD has a resolution path — never blocks indefinitely.
allowed-tools: Read, Write, Bash(find:*), Bash(ls:*)
argument-hint: "[task-id e.g. T-001] [sprint-id e.g. S1]"
---

# ASES `/ases-validate [task-id] [sprint-id]`
**Agent:** Execution (Sonnet / configured alternative) · **Scope:** Task · **Gate: verdict=PROCEED**

Parse: `TASK_ID` = first argument, `SPRINT_ID` = second argument.

## Input
Read `sprints/$SPRINT_ID/execution/tasks.json` (task entry for $TASK_ID),
`sprints/$SPRINT_ID/execution/tasks/$TASK_ID-plan.json`,
`sprints/$SPRINT_ID/design/lld.json`

Check file existence by reading `sprints/$SPRINT_ID/execution/tasks.json`, extracting `inputs.reads_from[]` for the task, then using the Read tool to verify each file path exists.

## Four Checks
1. `input_files_exist` — all files in `task.inputs.reads_from[]` exist
2. `interface_contract_intact` — lld interface for this file not drifted
3. `scope_boundary_clear` — task files don't overlap with in-progress tasks
4. `no_circular_dependency` — all `depends_on[]` tasks are `status: complete`

## Rules
- Pre-flight only — no code review
- HOLD must include `hold_reason` + `suggested_resolution`
- Never block indefinitely — every HOLD has a resolution

## Output
```
sprints/$SPRINT_ID/execution/validation_$TASK_ID.json   ← schema: format/json/validation.schema.json
```

PROCEED → `/ases-dev $TASK_ID $SPRINT_ID`
HOLD → resolve `hold_reason` → re-run
