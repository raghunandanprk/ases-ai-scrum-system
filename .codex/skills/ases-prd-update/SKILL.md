---
name: ases-prd-update
description: >
  ASES Sprint Design — Optionally update the PRD at sprint start when previous sprint
  learning changes product understanding. Invoke with /ases-prd-update [sprint-id] or
  after sprint_summary.json contains suggested_prd_updates. Diffs old vs new features,
  flags invalidated HLD/LLD sections, bumps prd_version. Sprint ceremony not escape hatch.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S2]"
---

# ASES `/ases-prd-update [sprint-id]`
**Agent:** Planner (Opus) · **Scope:** Sprint · **Optional**

## Input
Read `contracts/prd.json`, `sprints/$ARGUMENTS/ship/sprint_summary.json` (suggested_prd_updates),
`.ases/context.json`

## Process
1. Review `suggested_prd_updates` from previous sprint summary
2. Present proposed changes to PO — one change at a time
3. For each approved change: update prd.json, bump `prd_version`
4. Diff old vs new — identify changed/added/removed features
5. Flag which HLD modules or LLD files are invalidated
6. Log all changes as ADR entries in `decisions.json`

## Rules
- Changes must be PO-approved — cannot self-authorize
- Only update features in this sprint's scope
- Invalidated HLD sections flagged — not silently overwritten
- `prd_version` increments by 1 per update cycle

## Output
```
contracts/prd.json              ← updated, version bumped
docs/prd.md                ← updated
sprints/SN/design/prd_diff.json
.ases/decisions.json        ← change rationale added
```

## Gate
PO must approve all changes before `/ases-lld` runs.

## Next Step
After approval → `/ases-lld $ARGUMENTS`
