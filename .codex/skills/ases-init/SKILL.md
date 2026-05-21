---
name: ases-init
description: >
  ASES Phase 1 — Initialize the project container after roadmap approval.
  Invoke with /ases-init after PO approves /ases-roadmap. Creates the full folder structure,
  initializes context.json and decisions.json, and prepares the project for /ases-scaffold.
  Only runs once per project.
allowed-tools: Read, Write, Bash(mkdir:*)
---

# ASES `/ases-init`
**Agent:** System · **Scope:** Project · **Runs once**

## Input
Read `contracts/roadmap.json` (must be PO approved), `contracts/brief.json`, `contracts/hld.json`

## Creates — Monorepo Topology

```
backend/                          ← FastAPI / Python (filled by /ases-scaffold)
  src/                            ← root Python package goes here in scaffold
  tests/
    unit/
    integration/
    system/
  .env.example                    ← placeholder schema, real values added by PO
  db/                             ← migrations folder (populated in scaffold)
frontend/                         ← Next.js + Tailwind + shadcn/ui (filled by /ases-ui-scaffold)
  src/                            ← Gemini scaffolds the runnable app here directly
docs/
  brief.md  prd.md  hld.md  roadmap.md  context.md  decisions.md
contracts/
  brief.json  prd.json  hld.json  roadmap.json
  scaffold_spec.json + scaffold.json (post-scaffold)
.ases/
  context.json + context.md
  decisions.json + decisions.md   ← copies ADRs already written in /ases-hld
  global_context.json + global_context.md
sprints/
  S1/   S2/   ...                 ← one folder per sprint in roadmap
    design/
    execution/
      snapshots/
      tasks/
    ship/
format/json/
format/markdown/
assets/                           ← preserved if pre-existing
CHANGELOG.md
.gitignore
README.md
```

## Initializes
- `.ases/context.json` — full state with 8 lean fields (`project`, `sprint`,
  `phase`, `stage`, `last_completed`, `next`, `blockers`, `prd_version`) plus
  extended fields; `prd_version: 1`, `current_sprint: S1`
- `.ases/decisions.json` — copies ADR entries from `/ases-hld` with
  `module_refs[]` and `recall_keywords[]`
- `.ases/global_context.json` — empty entries array
- `CHANGELOG.md` — empty with header
- `backend/.env.example` — placeholder, schema documented (real `backend/.env` is created
  manually by PO before `/ases-scaffold` Step B.1, per security policy: secrets never
  auto-written by ASES)

## Output
```
.ases/context.json   ← schema: format/json/context.schema.json
.ases/global_context.json
docs/context.md
```

## Next Step
→ `/ases-scaffold`
