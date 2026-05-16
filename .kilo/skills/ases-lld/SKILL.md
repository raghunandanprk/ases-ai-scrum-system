---
name: ases-lld
description: >
  ASES Sprint Design — Generate the Low-Level Design scoped to the current sprint.
  Invoke with /ases-lld [sprint-id]. Reads hld.json and roadmap for this sprint's scope.
  Produces lld.json + lld.md with file map, function specs, interfaces[], depends_on[],
  and deps_manifest. Every file must have depends_on[] and interfaces[] — feeds task DAG.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-lld [sprint-id]`
**Agent:** Architect (Opus) · **Scope:** Sprint

## Input
Read `contracts/hld.json`, `contracts/roadmap.json`, `contracts/prd.json`, `.ases/context.json`,
`.ases/decisions.json`

Extract sprint scope: `roadmap.sprints[id=$ARGUMENTS].features` + `.modules`

## Process
1. Map every feature → specific files — no feature without a file owner
2. For each file: define functions[], interfaces (exports + expects), depends_on[]
3. Build dependency graph — verify no circular dependencies
4. Generate `deps_manifest` — packages, services, env_vars for this sprint
5. Write ADR entries for any new tradeoffs made

## Rules
- Scope ONLY to this sprint's modules
- Every file MUST have `depends_on[]` (can be `[]`) and `interfaces{}`
- `depends_on[]` drives task DAG — be precise
- `interfaces.exports` must match what consuming files expect
- All tradeoffs → `decisions.json`

## Output
```
sprints/$ARGUMENTS/design/lld.json           ← schema: format/json/lld.schema.json
sprints/$ARGUMENTS/design/lld.md             ← template: format/markdown/lld.template.md
sprints/$ARGUMENTS/design/deps_manifest.json
sprints/$ARGUMENTS/design/deps_manifest.md
.ases/decisions.json                         ← updated
```

## Next Step
→ `/ases-schema $ARGUMENTS`
