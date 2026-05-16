---
name: ases-tasks
description: >
  ASES Sprint Execution — Decompose the sprint LLD into an ordered task DAG with per-task
  plans, tests, and implementation guides. Invoke with /ases-tasks [sprint-id] after
  /ases-sprint-scaffold. Every task gets plan.json, plan.md, tests.json, tests.md.
  UI tasks flagged for UI track. execution_order[] resolves all dependencies.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-tasks [sprint-id]`
**Agent:** Task Manager (Opus) · **Scope:** Sprint

## Input
Read `sprints/$ARGUMENTS/design/lld.json`, `sprints/$ARGUMENTS/design/test_cases.json`,
`sprints/$ARGUMENTS/execution/analysis.json`, `.ases/decisions.json`

## Process
1. Create one task per lld file (type=create/modify)
2. Build dependency graph from `lld.depends_on[]`
3. Resolve DAG → `execution_order[]` (topological sort)
4. Identify `parallel_groups[]` — tasks with no interdependency
5. Flag UI tasks — any file in `frontend/` or component type
6. Per task: write plan.json + plan.md + tests.json + tests.md
7. Link `test_case_refs` from test_cases.json

## Per-Task plan.md Must Include
- Context anchor: last completed task, impacted files
- Implementation logic: pseudo-code + logic steps (reduces GLM reasoning tokens)
- Constraints: architectural rules from lld/schema
- Do Not Touch: explicit file boundaries
- Success criteria: manual + automated test command + definition of done
- Checkout prompt: GLM outputs 2-sentence summary after completion

## Rules
- Every task has `depends_on[]` resolved
- `test_case_refs` links to actual TC IDs
- UI tasks in `ui_tasks[]` list — routes to UI track
- `parallel_groups` verified — no hidden dependencies

## Output
```
sprints/$ARGUMENTS/execution/tasks.json          ← schema: format/json/tasks.schema.json
sprints/$ARGUMENTS/execution/tasks.md
sprints/$ARGUMENTS/execution/tasks/T-NNN-plan.json     ← per task
sprints/$ARGUMENTS/execution/tasks/T-NNN-plan.md       ← per task (implementation guide)
sprints/$ARGUMENTS/execution/tasks/T-NNN-tests.json    ← per task
sprints/$ARGUMENTS/execution/tasks/T-NNN-tests.md      ← per task
```

## Next Step
Has UI tasks → `/ases-ui-design $ARGUMENTS`
No UI tasks → begin with `/ases-validate [first-task-id] $ARGUMENTS`
