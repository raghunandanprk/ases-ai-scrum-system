---
name: ases-devops
description: >
  ASES Sprint Ship — Git commit after UAT approval. Invoke with /ases-devops [sprint-id]
  after /ases-uat APPROVED. Commit only runs if UAT is APPROVED or CONDITIONAL — the
  guard_commit logic in ases-hook.py enforces this. Structured commit message auto-generated from
  sprint_summary. Future hooks declared for branch strategy, CI, deploy.
allowed-tools: Read, Write, Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-devops [sprint-id]`
**Agent:** Developer (Claude Sonnet) · **Scope:** Sprint · **Runs after:** uat.APPROVED

## Pre-Check
Read `sprints/$ARGUMENTS/ship/uat_report.json` — verify `verdict` is `APPROVED | CONDITIONAL`.
Read `.ases/context.json` — verify `current_phase` is `SPRINT_SHIP`.

The `ases-hook.py` commit guard (Job 3) enforces this at the system level.

## Current status
```bash
!`git status`
!`git diff HEAD --stat`
```

## Commit Process
1. Stage sprint files: source code, tests, migrations, UI scaffold
2. Generate structured commit message from sprint_summary
3. Execute commit

## Commit Message Format
```
feat($ARGUMENTS): {sprint_goal}

Features: {features_shipped}
Tasks: {completed} completed, {deferred} deferred
UAT: {verdict}
Tech debt: {count} items logged

ASES-Sprint: $ARGUMENTS
```

## Rules
- NEVER commit if `uat_report.verdict = REJECTED`
- NEVER commit if `current_phase != SPRINT_SHIP`
- Include test files + migration files
- DO NOT commit `.env` files — `.env.example` only

## Output
```
sprints/$ARGUMENTS/ship/devops_log.json   ← schema: format/json/devops_log.schema.json
sprints/$ARGUMENTS/ship/devops_log.md
```

## Future Hooks (not yet implemented)
`branch_strategy | pr_creation | ci_trigger | deploy_pipeline`

## Next Step
→ `/ases-final-audit $ARGUMENTS`
