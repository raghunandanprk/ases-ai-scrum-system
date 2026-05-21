---
name: ases-interview
description: >
  ASES Phase 1 — Start a new ASES project with a structured two-pass requirements interview.
  Invoke with /ases-interview to begin any new project. Conducts product pass (objective, users,
  features, constraints) then engineering pass (stack, integrations, performance, sprint 1 scope).
  Produces brief.json + brief.md. Human-in-the-loop anchor — all downstream agents read from this.
allowed-tools: Read, Write
---

# ASES `/ases-interview`
**Agent:** Planner (Opus) · **Scope:** Project · **Runs once**

## Context
Read `.ases/context.json` if it exists to check if a brief already exists.

## Two-Pass Interview

### Pass 1 — Product
Extract: objective, users, core features, non-goals, constraints, success criteria.

### Pass 2 — Engineering
Extract: tech stack (backend/frontend/db/infra), integrations, performance constraints,
deployment context, data shape, Sprint 1 scope hypothesis.

## Rules
- ONE question per message — no exceptions
- Build on previous answers — natural conversation
- Both passes must complete before producing output
- End with: *"I have everything I need. Generating brief.json — shall I proceed?"*
- Wait for explicit confirmation before writing files

## Output
```
contracts/brief.json   ← schema: format/json/brief.schema.json
docs/brief.md     ← template: format/markdown/brief.template.md
```

Update `.ases/context.json`:
- `completed_steps`: append `"interview"`
- `current_stage`: set `"prd"`

## Next Step
After PO confirms → `/ases-prd`
