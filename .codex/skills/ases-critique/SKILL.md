---
name: ases-critique
description: >
  ASES Sprint Execution — Opus audits GLM's code output. Invoke with /ases-critique
  [task-id] [sprint-id] after every /ases-dev or /ases-fix. Four lenses: spec, contract,
  test, security. Reads decisions.json first — distinguishes tradeoff from bug. Max 3
  iterations then auto-escalates. Detection only — never rewrites code.
allowed-tools: Read, Write
argument-hint: "[task-id e.g. T-001] [sprint-id e.g. S1]"
---

# ASES `/ases-critique [task-id] [sprint-id]`
**Agent:** Reasoning (Opus / configured alternative) · **Scope:** Task · **Max iterations:** 3–5 (smart cap)

Parse: `TASK_ID` = first arg, `SPRINT_ID` = second arg.

## Input
Read task files (code written by Developer),
`sprints/$SPRINT_ID/execution/tasks/$TASK_ID-plan.json`,
`sprints/$SPRINT_ID/design/lld.json`,
`.ases/decisions.json` ← **READ FIRST before flagging anything**,
`sprints/$SPRINT_ID/design/test_cases.json` (refs for this task)

## Four Lenses

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
Call graph connectivity — is new code reachable from entry points?
Orphaned functions, dead imports, missing call edges?
Use `graphify query` or `graphify explain` for targeted checks.
Skip if context bracket is DEPLETED/CRITICAL.

## Rules
- Read `decisions.json` FIRST — set `is_adr_tradeoff: true` for known decisions
- Detection only — no rewrites
- `fix_instruction` must be specific + actionable
- `iteration ≥ 3` AND `FIX_REQUIRED` AND `issues_remaining ≥ previous_issues_remaining` → force verdict to `ESCALATE`
- `iteration ≥ 5` → force verdict to `ESCALATE` (hard cap regardless of progress)

## Output
```
sprints/$SPRINT_ID/execution/critique_$TASK_ID.json   ← schema: format/json/critique.schema.json
sprints/$SPRINT_ID/execution/critique_$TASK_ID.md
```

CLEAN → update `tasks.json` status=complete → update `context.json` → next task
FIX_REQUIRED → `/ases-fix $TASK_ID $SPRINT_ID`
ESCALATE → present to PO with structured options:
  1. **Accept with tech debt** → mark complete, log TD entry in decisions.json
  2. **Rollback** → `/ases-rollback $TASK_ID $SPRINT_ID` → task returns to pending
  3. **Simplify** → PO edits plan.md, reset iteration_count → re-run `/ases-dev`
  4. **Defer** → mark deferred, create CF entry in global_context.json
  5. **PRD issue** → `/ases-prd-update` next sprint
