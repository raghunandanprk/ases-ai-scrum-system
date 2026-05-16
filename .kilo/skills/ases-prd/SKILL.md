---
name: ases-prd
description: >
  ASES Phase 1 — Generate the Product Requirements Document from brief.json.
  Invoke with /ases-prd after /ases-interview completes. Produces prd.json + prd.md
  with features, acceptance_criteria, non-functional requirements, and sprint allocation.
  Every feature MUST have acceptance_criteria — this seeds test-spec and UAT.
allowed-tools: Read, Write
---

# ASES `/ases-prd`
**Agent:** Planner (Opus) · **Scope:** Project · **Versioned on update**

## Input
Read `contracts/brief.json` (required), `.ases/context.json`

## Process
1. Structure features from brief `core_features` — each gets `id`, `priority`, `sprint_allocation`
2. Write `acceptance_criteria[]` per feature — derive from `success_criteria` in brief
3. Mark `non_goals` explicitly — prevents downstream scope creep
4. Populate `non_functional` from `performance_constraints` in brief
5. Assign `sprint_allocation` per feature using `sprint_1_hypothesis`

## Rules
- Every feature needs ≥1 `acceptance_criteria` entry
- Each AC must be testable — verifiable by human or automated test
- `non_goals` must be explicit
- Write back: bump `prd_version`, extract `users[]` + `constraints[]` to `context.json`

## Output
```
contracts/prd.json   ← schema: format/json/prd.schema.json
docs/prd.md     ← template: format/markdown/prd.template.md
```

## Gate
Present `docs/prd.md` to PO. Wait for confirmation before proceeding.

## Next Step
After PO confirms → `/ases-hld`
