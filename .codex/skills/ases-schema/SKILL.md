---
name: ases-schema
description: >
  ASES Sprint Design — Generate the data schema scoped to the current sprint.
  Invoke with /ases-schema [sprint-id] after /ases-lld completes. Scoped to this sprint's
  data models only. Each entity references its HLD module. Produces schema.json + schema.md.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-schema [sprint-id]`
**Agent:** Architect (Opus) · **Scope:** Sprint

## Input
Read `sprints/$ARGUMENTS/design/lld.json`, `contracts/hld.json`, `contracts/prd.json`

## Process
1. Identify data entities from lld files touching persistence layer
2. For each entity: define fields, types, indexes, relationships
3. Map every entity to its `hld_module`
4. Check: no entity missing from lld, no lld model missing from schema
5. Define migrations needed for this sprint

## Rules
- Every entity has `hld_module` reference
- Relationships explicit — no implied foreign keys
- Indexes justified — list query patterns they support
- Schema changes from prior sprints → `decisions.json`

## Output
```
sprints/$ARGUMENTS/design/schema.json   ← schema: format/json/schema.schema.json
sprints/$ARGUMENTS/design/schema.md
```

## Next Step
→ `/ases-test-spec $ARGUMENTS`
