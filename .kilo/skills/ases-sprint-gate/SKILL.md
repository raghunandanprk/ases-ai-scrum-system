---
name: ases-sprint-gate
description: >
  ASES Sprint Design — Validate all sprint design documents before execution begins.
  Invoke with /ases-sprint-gate [sprint-id] after /ases-test-spec completes. Runs five
  consistency checks. FAIL verdict locks Phase 2. This is the determinism gate — if it
  FAILs, fix the flagged document and re-run. PO must approve PASS before /ases-analyze.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-sprint-gate [sprint-id]`
**Agent:** Critic (Opus) · **Scope:** Sprint · **Gate: verdict=PASS**

## Input
Read all sprint design outputs for `$ARGUMENTS`:
`sprints/$ARGUMENTS/design/lld.json`, `sprints/$ARGUMENTS/design/schema.json`,
`sprints/$ARGUMENTS/design/test_cases.json`, `sprints/$ARGUMENTS/design/deps_manifest.json`,
`contracts/roadmap.json`, `.ases/context.json`

## Step 0 — Schema Validation
For each design file, validate against its schema in `format/json/`:
```bash
python .claude/hooks/validate_schema.py sprints/$ARGUMENTS/design/lld.json lld
python .claude/hooks/validate_schema.py sprints/$ARGUMENTS/design/schema.json schema
python .claude/hooks/validate_schema.py sprints/$ARGUMENTS/design/test_cases.json test_cases
python .claude/hooks/validate_schema.py sprints/$ARGUMENTS/design/deps_manifest.json deps_manifest
```
If any validation fails → FAIL with `"schema_validation_error"` details.

## Five Checks

1. `lld_files_cover_roadmap_scope` — every feature in roadmap[sprint] has file coverage
2. `schema_entities_match_lld_models` — every persistence-layer file has schema entity
3. `test_cases_cover_all_ac` — every AC for this sprint has ≥1 test case
4. `deps_manifest_complete` — all imports in lld files have manifest entries
5. `no_lld_conflicts_with_previous_sprint` — new files don't conflict with existing (n/a S1)

## Rules
- FAIL on any check → Phase 2 locked — tell PO exactly which document to fix
- PASS with warnings → proceed, log warnings to `context.json open_issues[]`
- Detection only — do not attempt to fix anything

## Output
```
sprints/$ARGUMENTS/design/sprint_gate.json   ← schema: format/json/sprint_gate.schema.json
sprints/$ARGUMENTS/design/sprint_gate.md
.ases/context.json                          ← phase_status updated
```

## ⚠ Human Gate
FAIL → Direct PO to fix document → re-run `/ases-sprint-gate`
PASS → Present `sprint_gate.md` to PO → await approval → `/ases-analyze $ARGUMENTS`

---

## On PASS Verdict — Write Sprint Context (Level 2)

When verdict = PASS, write `.ases/sprint_context.json`:

```json
{
  "sprint_id": "$ARGUMENTS",
  "sprint_goal": "<from roadmap>",
  "features_in_scope": ["F-001"],
  "modules_in_scope": ["M-001"],
  "tasks_status": {
    "total": 0,
    "complete": 0,
    "in_progress": 0,
    "pending": 0,
    "deferred": 0
  },
  "open_issues": [],
  "carry_forward_from_previous": [],
  "relevant_decisions": ["DS-001"],
  "known_constraints": [],
  "written_at": "<ISO-8601>",
  "written_by": "ases-sprint-gate"
}
```

`relevant_decisions[]` — populate from `.ases/decisions.json` where `module_refs`
intersects `modules_in_scope`. Use IDs only (e.g. `"DS-001"`) — hook resolves full text.

Write `.ases/sprint_context.md` — human-readable sprint brief for PO.
