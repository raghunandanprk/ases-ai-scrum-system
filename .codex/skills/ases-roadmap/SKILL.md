---
name: ases-roadmap
description: >
  ASES Phase 1 — Generate the sprint roadmap from prd.json and hld.json.
  Invoke with /ases-roadmap after /ases-hld is confirmed. Groups features into sprints
  by dependency and priority. Produces roadmap.json + roadmap.md. MANDATORY human approval
  gate — do NOT proceed to /ases-init without explicit PO sign-off.
allowed-tools: Read, Write
---

# ASES `/ases-roadmap`
**Agent:** Planner (Opus) · **Scope:** Project · **⚠ Mandatory PO approval**

## Input
Read `contracts/prd.json`, `contracts/hld.json`

## Process
1. Group features into sprints by dependencies and priority
2. Assign modules to sprints — coherent module sets per sprint
3. Write clear `goal` per sprint (one sentence)
4. Log `deferred[]` items with reasons + target sprint
5. Verify Sprint 1 is independently buildable — no external sprint dependencies

## Rules
- Sprint 1 must be achievable — not the entire product
- Every feature appears in exactly one sprint or `deferred`
- `dependencies_on[]` references sprint IDs not feature IDs
- Deferred items need a reason — never blank

## Output
```
contracts/roadmap.json   ← schema: format/json/roadmap.schema.json
docs/roadmap.md
```

## ⚠ Mandatory Human Gate
Present `docs/roadmap.md` to PO.
**Do NOT run `/ases-init` without explicit PO approval.**
This gate governs the entire project sprint allocation.

## Next Step
After PO approves → `/ases-init`
