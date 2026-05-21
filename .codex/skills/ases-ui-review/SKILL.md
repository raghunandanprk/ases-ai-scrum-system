---
name: ases-ui-review
description: >
  ASES Sprint Execution UI Track — Opus validates Gemini's UI spec against PRD acceptance
  criteria and HLD module boundaries. Invoke with /ases-ui-review [sprint-id] after
  /ases-ui-design. APPROVED unlocks /ases-ui-scaffold. REVISION_REQUIRED loops back to
  /ases-ui-design with critique. Detection only — never redesigns components.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-ui-review [sprint-id]`
**Agent:** Critic (Opus) · **Scope:** Sprint · **Gate: verdict=APPROVED**

## Input
Read `sprints/$ARGUMENTS/execution/ui_spec.json`, `contracts/prd.json`, `contracts/hld.json`

## Three Checks
1. `ac_coverage` — every UI-related AC has a component addressing it
2. `module_boundary` — components don't cross HLD module boundaries
3. `api_contract` — API dependencies match actual lld interface definitions

## Rules
- Detection only — do not redesign
- REVISION_REQUIRED must include specific fix instructions per component
- APPROVED may include warnings — logged but don't block scaffold

## Output
```
sprints/$ARGUMENTS/execution/ui_review.json
sprints/$ARGUMENTS/execution/ui_review.md
```

REVISION_REQUIRED → return to `/ases-ui-design $ARGUMENTS` with critique
APPROVED → `/ases-ui-scaffold $ARGUMENTS`
