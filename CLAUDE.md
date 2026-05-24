# ASES v3.2 — AI Scrum Engineering System

<!-- ASES-MANAGED: Do not remove -->
## Context Integration
Obey all `<ases-state>` blocks injected by `ases-hook.py`. They are live project state.
<!-- END ASES-MANAGED -->

## Models
| Role | Default (Claude Code) | Tasks |
|---|---|---|
| Reasoning | Opus 4.7 | Plan, architect, critique, test design |
| Execution | Sonnet 4.6 | Code, fix, scaffold, test, validate |
| UI | Gemini 3.1 Pro | UI spec + scaffold |
| Decision | Human (PO) | 6 gates per sprint |

> Model IDs are platform-specific — see each platform's `system.yaml`.
> Kilo Code (via OpenCode Go): GLM 5.1 / DeepSeek V4 Pro / Kimi K2.6 · Codex: GPT 5.5 / GPT 5.3 Codex

## Pipeline

**Project Start** — `interview → prd → hld → roadmap ⚑PO → init → scaffold`

**Phase 1 · Design** — `prd-update? → lld → schema → test-spec → sprint-gate ⚑PO`

**Phase 2 · Execution**
```
analyze → sprint-scaffold → tasks
ui-design → ui-review → ui-scaffold           [if UI]
batch: batch-exec → batch-critique             [primary, per-task sub-agents]
per-task: validate → dev → critique ⟳ fix      [fallback]
sprint-close
```

**Phase 3 · Ship**
```
test-impl → test-run → integration-test → system-test
                ↑              ↑
            fix loop ×3    fix loop ×3
uat ⚑PO → devops → final-audit ⚑PO → release
```

## Context Levels
| L | File | Loaded |
|---|---|---|
| 3 | `.ases/context.json` | Always (8 fields) |
| 2 | `.ases/sprint_context.json` | Active sprint |
| 1 | `.ases/global_context.json` | `/ases-inject [IDs]` only |

IDs: `SP-` sprint · `DS-` decision · `TD-` debt · `FT-` feature · `RI-` risk · `CF-` carry-forward

## Structure
```
/.ases/          state (context, sprint_context, decisions, global_context)
/.claude/        skills(36), agents(6), hooks, system.yaml
/format/         schemas + templates (excluded)
/docs/           PO docs (excluded)
/contracts/      agent JSON contracts (excluded)
/sprints/SN/     design/ · execution/ · ship/
/backend/        FastAPI + tests/{unit,integration,system}
/frontend/       React/Next (locked after ui-scaffold)
/graphify-out/   knowledge graph (excluded, auto-built)
```

## Hard Rules
1. JSON+MD dual format every document
2. Write only `output_files[]` from task plan — no scope creep
3. Critique smart cap: 3 if stalling, 5 max → escalate PO
4. Critic detects only — never rewrites code
5. `scaffold_spec.json` gates execution — Reasoning writes spec first
6. Execution agent never touches UI scaffold — only `integration_points`
7. Git commit only after UAT — `ases-hook.py` enforces
8. Schema validation at every gate transition
9. Every tradeoff → `DS-NNN` ADR with `module_refs[]`
10. Tests from `acceptance_criteria` only — naming: `test_{tc_id}_{desc}`
11. `/test-run` required before integration tests
12. Phase 3 fix loop: max 3 iterations then escalate
13. Sprint-close blocks if any task `in_progress`

## Gates — Stop and Wait
1. After `/roadmap` · 2. After `/sprint-gate` PASS · 3. Any `ESCALATE`
4. `/uat` PO review · 5. After `/final-audit` SHIP · 6. Any `BLOCK`

*ASES v3.2 · 36 skills · 6 agents · 3 context levels · 13 rules · 6 gates · Claude Code + Kilo Code + OpenAI Codex*
