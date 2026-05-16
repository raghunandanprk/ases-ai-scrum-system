---
name: ases-hld
description: >
  ASES Phase 1 — Generate the High-Level Design from prd.json and brief.json.
  Invoke with /ases-hld after /ases-prd is confirmed. Produces hld.json + hld.md with
  system overview, module map, data flows, external dependencies, and risk register.
  Every architectural tradeoff MUST produce an ADR entry in decisions.json.
allowed-tools: Read, Write
---

# ASES `/ases-hld`
**Agent:** Architect (Opus) · **Scope:** Project

## Input
Read `contracts/prd.json`, `contracts/brief.json`, `.ases/decisions.json`

## Process
1. Write `system_overview` — one paragraph architecture narrative
2. Map `modules[]` — every PRD feature must map to ≥1 module
3. Define `data_flow[]` — trace data between modules
4. List `external_dependencies` from `brief.engineering.known_integrations`
5. Build `risks[]` from `brief.risks` + new architectural risks identified
6. For every non-obvious design choice → write ADR entry to `decisions.json`

## Rules
- Every PRD feature maps to a module — no orphaned features
- Every module has explicit `interfaces[]` + `dependencies[]`
- Every tradeoff → ADR entry with rationale + alternatives considered
- `risks[]` — critical severity must have mitigation defined
- No file-level detail here — that belongs in `/ases-lld`

## Output
```
contracts/hld.json        ← schema: format/json/hld.schema.json
docs/hld.md          ← template: format/markdown/hld.template.md
.ases/decisions.json  ← updated with new ADR entries
```

## Gate
Present `docs/hld.md` to PO. Wait for confirmation before proceeding.

## Next Step
After PO confirms → `/ases-roadmap`
