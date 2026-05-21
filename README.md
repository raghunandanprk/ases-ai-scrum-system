# ASES — AI Scrum Engineering System

> *This is not prompting. This is an AI software factory.*

ASES is a structured, Scrum-based engineering system that runs inside **Claude Code**, **Kilo Code**, and **OpenAI Codex**. It turns an open-ended AI session into a disciplined delivery pipeline — with defined roles, schema-validated outputs, human approval gates, hook-based context injection, and knowledge-graph-assisted code analysis — from first idea to production release.

---

## Table of Contents

- [What ASES Actually Is](#what-ases-actually-is)
- [Why It Exists](#why-it-exists)
- [How It Works](#how-it-works)
- [The Full Pipeline](#the-full-pipeline)
- [Context Architecture](#context-architecture)
- [Model Allocation](#model-allocation)
- [Skill Reference](#skill-reference)
- [Folder Structure](#folder-structure)
- [Hard Rules](#hard-rules)
- [Human Gates](#human-gates)
- [Quick Start](#quick-start)
- [Platform Support](#platform-support)
- [Requirements](#requirements)
- [Who This Is For](#who-this-is-for)

---

## What ASES Actually Is

Most AI coding workflows are one of two things: a single big prompt in `CLAUDE.md`, or a loose collection of slash commands with no enforcement between them. Both break down the moment a project gets complex.

ASES is neither. It is a three-phase sprint engine with:

- **Hook-based context injection** at three levels (lean, sprint, global) — loaded automatically, not manually pasted
- **Dual-file outputs** at every stage — `name.json` for agents, `name.md` for humans
- **Schema validation at every gate** — nothing advances until it passes
- **Batch execution** — combined validate+dev+critique in single sessions for token efficiency
- **A mandatory critique loop** with 5 lenses (spec, contract, test, security, structural) — up to 5 iterations before escalation
- **Knowledge graph integration** (Graphify) — tree-sitter AST analysis provides structural awareness to analyze and critique skills
- **6 human approval gates per sprint** — the Product Owner is part of the system, not an afterthought
- **A typed architectural decision log** (`decisions.json`) — every tradeoff gets a permanent `DS-NNN` ID
- **Multi-model routing** — Opus for planning and critique, Sonnet for execution, Gemini for UI scaffolding
- **Cross-platform** — runs identically on Claude Code, Kilo Code, and OpenAI Codex

---

## Why It Exists

When you use an LLM to build something real, a few things happen:

- Context grows and gets messy across sessions
- Outputs drift from the original spec
- You repeat the same decisions because nothing was recorded
- Token usage climbs because everything is always in context
- The agent "completes" tasks that aren't actually done

ASES fixes each of these with structure. Context is layered and injected by hook. Decisions are logged with typed IDs. Outputs are validated by schema. Completion requires critique, not just generation. The human stays in control at every meaningful boundary.

---

## How It Works

The primary execution mode is **batch**:

```
/ases-batch-exec → /ases-batch-critique → /ases-fix (per task, if needed)
```

Batch-exec orchestrates per-task sub-agent dispatch — each task runs in an isolated context window via the platform's sub-agent tool (`Agent` on Claude Code, `new_task` on Kilo Code, `runSubagent` on Codex). Batch-critique does the same for the 5-lens critique pass. This provides context isolation, granular failure handling, and parallelism.

For targeted re-entry or individual tasks, the **per-task fallback** works:

```
/ases-validate → /ases-dev → /ases-critique → /ases-fix
```

Above both loops, a full sprint flows through three phases:

**Phase 1 — Design:** Define the sprint, produce LLD + schema + test spec, get gate approval before any code runs.

**Phase 2 — Execution:** Analyze, scaffold, build (batch or per-task), critique, fix. UI tasks go through a separate Gemini-driven path. Knowledge graph is auto-updated at key pipeline points.

**Phase 3 — Ship:** Unit → test-run → integration → system → UAT → DevOps → final audit → release. Fix loops capped at 3 iterations per failing stage. Git commits only happen after UAT approval, enforced by `ases-hook.py` (Claude) / `ases-guard.ts` (Kilo) / `ases-guard.sh` + `ases-guard.ps1` (Codex).

---

## The Full Pipeline

### Project Start (once)

```
/ases-interview → /ases-prd → /ases-hld → /ases-roadmap ⚑PO → /ases-init → /ases-scaffold
```

### Per Sprint

**Phase 1 — Sprint Design**
```
/ases-prd-update (optional) → /ases-lld → /ases-schema → /ases-test-spec → /ases-sprint-gate ⚑PO
```

**Phase 2 — Sprint Execution**
```
/ases-analyze → /ases-sprint-scaffold → /ases-tasks
/ases-ui-design → /ases-ui-review → /ases-ui-scaffold        [if UI tasks]
batch: /ases-batch-exec → /ases-batch-critique                [primary]
per-task: /ases-validate → /ases-dev → /ases-critique ⟳ fix   [fallback]
/ases-sprint-close
```

**Phase 3 — Sprint Ship**
```
/ases-test-impl → /ases-test-run → /ases-integration-test → /ases-system-test
                       ↑                    ↑
                   fix loop ×3           fix loop ×3
/ases-uat ⚑PO → /ases-devops → /ases-final-audit ⚑PO → /ases-release
```

---

## Context Architecture

ASES separates context into three levels, each with its own file and injection rule:

| Level | File | When Loaded | Access Pattern |
|-------|------|-------------|----------------|
| 3 — Lean | `.ases/context.json` | Hook — every session | Always available (8 fields) |
| 2 — Sprint | `.ases/sprint_context.json` | Hook — active sprint only | Loaded during sprint sessions |
| 1 — Global | `.ases/global_context.json` | Explicit call only | `/ases-inject [IDs]` or PO commands |

Global context uses identifier-addressed entries:

| Prefix | Type |
|--------|------|
| `SP-NNN` | Sprint digest |
| `DS-NNN` | Architectural decision |
| `TD-NNN` | Tech debt item |
| `FT-NNN` | Feature record |
| `RI-NNN` | Risk item |
| `CF-NNN` | Carry-forward |

Surgical injection of specific entries: `/ases-inject DS-003 SP-001`

This means lean context is always available without token waste, sprint context exists only while relevant, and global context is never loaded speculatively.

---

## Model Allocation

| Role | Model | Tasks |
|------|-------|-------|
| Reasoning | Opus 4.7 | Planning, architecture, critique, test design |
| Execution | Sonnet 4.6 | Code generation, fixes, scaffolding, test implementation, validation |
| Worker | Sub-agent | Per-task isolated execution (worker-dev) and critique (worker-critic) |
| UI | Gemini 3.1 Pro | UI spec + Next.js/React scaffold |
| Decision | Human (PO) | 6 mandatory approval gates per sprint |

All models are configurable via `system.yaml`. Sonnet never touches the Gemini UI scaffold — only declared `integration_points`. Role separation is enforced, not suggested.

---

## Skill Reference

### Project Setup (6 skills)
| Skill | Agent | Description |
|-------|-------|-------------|
| `/ases-interview` | Opus | Structured project discovery — goals, constraints, scope |
| `/ases-prd` | Opus | Product Requirements Document (JSON + Markdown) |
| `/ases-hld` | Opus | High-Level Design — modules, data flows, API boundaries |
| `/ases-roadmap` | Opus | Sprint roadmap across milestones ⚑PO |
| `/ases-init` | System | Bootstraps `.ases/`, folders, and state files |
| `/ases-scaffold` | Opus→Sonnet | Two-step project scaffold + initial graphify build |

### Sprint Design — Phase 1 (5 skills)
| Skill | Agent | Description |
|-------|-------|-------------|
| `/ases-prd-update` | Opus | Updates PRD when scope changes mid-project |
| `/ases-lld` | Opus | Low-Level Design — component specs, interfaces |
| `/ases-schema` | Opus | Database / data model schema |
| `/ases-test-spec` | Opus | Test cases from PRD acceptance criteria |
| `/ases-sprint-gate` | Opus | Gate check — validates Phase 1 before execution ⚑PO |

### Sprint Execution — Phase 2 (17 skills)
| Skill | Agent | Description |
|-------|-------|-------------|
| `/ases-analyze` | Opus | Codebase analysis + graph-assisted drift detection |
| `/ases-sprint-scaffold` | Opus→Sonnet | Sprint-level scaffolding + graphify update |
| `/ases-tasks` | Opus | Task decomposition into `tasks.json` |
| `/ases-ui-design` | Gemini | UI spec generation |
| `/ases-ui-review` | Opus | UI design review before scaffold |
| `/ases-ui-scaffold` | Gemini | UI component scaffold (locked after creation) |
| `/ases-validate` | Sonnet | Pre-execution 4-check validation |
| `/ases-dev` | Sonnet | Single-task implementation |
| `/ases-critique` | Opus | 5-lens critique (spec, contract, test, security, structural) |
| `/ases-fix` | Sonnet | Targeted fix from critique findings |
| `/ases-batch-exec` | Orchestrator→Worker | Per-task sub-agent validate+dev dispatch + graphify update |
| `/ases-batch-validate` | Sonnet | Standalone batch validation |
| `/ases-batch-dev` | Sonnet | Standalone batch implementation |
| `/ases-batch-critique` | Orchestrator→Worker | Per-task sub-agent 5-lens critique dispatch |
| `/ases-sprint-close` | Opus | Graphify update + close sprint, produce carry-forwards |

### Sprint Ship — Phase 3 (7 skills)
| Skill | Agent | Description |
|-------|-------|-------------|
| `/ases-test-impl` | Sonnet | Unit test implementation from test spec |
| `/ases-test-run` | Sonnet | Execute tests with 3-iteration fix loop |
| `/ases-integration-test` | Opus→Sonnet | Integration test scenarios + execution |
| `/ases-system-test` | Opus→Sonnet | Full system test |
| `/ases-uat` | Human | PO reviews running system ⚑PO |
| `/ases-devops` | Sonnet | Deployment pipeline and environment setup |
| `/ases-final-audit` | Opus | Pre-release audit — SHIP or BLOCK ⚑PO |
| `/ases-release` | Sonnet | Production release after SHIP + PO gate |

### Utilities (2 skills)
| Skill | Agent | Description |
|-------|-------|-------------|
| `/ases-inject` | Human | Selectively inject global context entries by ID |
| `/ases-graphify` | Sonnet | Build/update knowledge graph (tree-sitter AST, zero LLM cost) |

---

## Folder Structure

```
/.ases/                          ← System state (hook reads, never project outputs)
  context.json + context.md          Level 3: lean, always loaded
  sprint_context.json                Level 2: sprint-scoped
  global_context.json                Level 1: explicit only
  decisions.json + decisions.md      ADR log, PO-managed

/.claude/                        ← Claude Code platform
  hooks/ases-hook.py                 CARL-inspired context hook
  skills/ases-*/SKILL.md             36 skills
  agents/{planner,architect,         Agent role definitions (6 total)
    critic,developer,
    worker-dev,worker-critic}.md
  system.yaml                       Model + context config

/.kilo/                          ← Kilo Code platform (mirror)
  plugin/ases-guard.ts               TypeScript hook port
  skills/ agents/ rules/             Same 36 skills
  kilo.jsonc                         Permissions config
  system.yaml                       Same model config

/.codex/                         ← OpenAI Codex platform (desktop / VS Code)
  hooks/ases-guard.sh                Bash hook port
  hooks/ases-guard.ps1               PowerShell hook port (Windows)
  hooks.json                         Hook registration
  config.toml                        Project config (TOML)
  AGENTS.md                          Codex-specific instructions
  skills/ases-*/SKILL.md             Same 36 skills
  system.yaml                        Same model config

/.github/agents/                 ← VS Code / Codex agent definitions
  {architect,developer,              6 agents in .agent.md format
   critic,planner,
   worker-dev,worker-critic}.agent.md

/format/                         ← ASES schemas + templates (excluded from scan)
/docs/                           ← PO documents (excluded from scan)
/contracts/                      ← Machine-readable JSON contracts (excluded)

/sprints/SN/
  design/                        ← Phase 1: lld, schema, test_cases, sprint_gate
  execution/                     ← Phase 2: analysis, tasks, snapshots/
  ship/                          ← Phase 3: test_suite, uat, audit, release

/backend/                        ← FastAPI / Python
/frontend/                       ← Next.js / React (locked after UI scaffold)
/backend/tests/{unit,integration,system}/

/graphify-out/                   ← Knowledge graph (excluded, auto-built)
  graph.json · GRAPH_REPORT.md · graph.html
```

---

## Hard Rules

These are never negotiated. The system enforces them.

1. JSON+MD dual format every document
2. Write only `output_files[]` from task plan — no scope creep
3. Critique smart cap: 3 if stalling, 5 max → escalate PO
4. Critic detects only — never rewrites code
5. `scaffold_spec.json` gates execution — Reasoning writes spec first
6. Execution agent never touches UI scaffold — only `integration_points`
7. Git commit only after UAT — hook enforces
8. Schema validation at every gate transition
9. Every tradeoff → `DS-NNN` ADR with `module_refs[]`
10. Tests from `acceptance_criteria` only — naming: `test_{tc_id}_{desc}`
11. `/test-run` required before integration tests
12. Phase 3 fix loop: max 3 iterations then escalate
13. Sprint-close blocks if any task `in_progress`

---

## Human Gates

ASES stops and waits at 6 mandatory points per sprint. These cannot be bypassed.

| Gate | Trigger |
|------|---------|
| 1 | After `/ases-roadmap` — before `/ases-init` |
| 2 | After `/ases-sprint-gate` PASS — before `/ases-analyze` |
| 3 | Any `ESCALATE` verdict from `/ases-critique` |
| 4 | `/ases-uat` — PO reviews the running system |
| 5 | After `/ases-final-audit` SHIP — before `/ases-release` |
| 6 | Any `BLOCK` verdict — directed surgical re-entry |

---

## Quick Start

### Claude Code

```bash
# 1. Copy ASES into your project
cp -r ases-ai-scrum-system/.claude your-project/
cp ases-ai-scrum-system/CLAUDE.md your-project/
cp ases-ai-scrum-system/.claudeignore your-project/

# 2. Open in Claude Code
cd your-project && claude

# 3. Start
/ases-interview
```

### Kilo Code

```bash
# 1. Copy ASES into your project
cp -r ases-ai-scrum-system/.kilo your-project/
cp ases-ai-scrum-system/AGENTS.md your-project/
cp ases-ai-scrum-system/.kilocodeignore your-project/

# 2. Open in Kilo Code and start
/ases-interview
```

### OpenAI Codex (Desktop / VS Code)

```bash
# 1. Copy ASES into your project
cp -r ases-ai-scrum-system/.codex your-project/
cp -r ases-ai-scrum-system/.github your-project/
cp ases-ai-scrum-system/AGENTS.md your-project/

# 2. Open in Codex desktop app or VS Code with Codex extension
# 3. Trust the project when prompted
# 4. Start
/ases-interview
```

All platforms share `.ases/`, `format/`, `contracts/`, `docs/`, and `sprints/`. Copy those too for a full setup, or let `/ases-init` create them.

---

## Platform Support

| Platform | Config File | Hook | Sub-Agent Tool | Status |
|----------|-------------|------|----------------|--------|
| Claude Code | `CLAUDE.md` + `.claude/` | `ases-hook.py` (Python) | `Agent` | ✅ Full |
| Kilo Code | `AGENTS.md` + `.kilo/` | `ases-guard.ts` (TypeScript) | `new_task` | ✅ Full |
| OpenAI Codex | `AGENTS.md` + `.codex/` + `.github/agents/` | `ases-guard.sh` / `ases-guard.ps1` | `runSubagent` | ✅ Full |

Skills, agents, and system.yaml are identical across platforms. Only the hook mechanism, agent format, and platform config differ.

---

## Requirements

- **Claude Code**, **Kilo Code**, or **OpenAI Codex** — ASES runs inside any of these
- **Git** — enforced at release gate
- **Graphify** (optional) — `pip install graphifyy` for knowledge graph features
- **Gemini access** (optional) — required for UI scaffold path only
- **jq** (Codex only, optional) — required for Bash hook on non-Windows; PowerShell hook has no external deps

---

## Who This Is For

**Developers building real, multi-sprint projects with AI coding assistants** who want the structure of a software delivery team without the overhead of actually managing one.

Specifically:
- You've hit the wall where unstructured AI sessions produce inconsistent outputs
- You want decisions recorded, not just made
- You want the agent to critique its own work, not just submit it
- You want a human checkpoint before things go to production
- You want to know exactly what context the agent has access to at any point

**Not for:** one-off scripts, quick experiments, or single-session tasks. ASES has setup overhead — it pays off on projects that span multiple sprints.

---

## Command Centre

ASES ships with a visual reference interface at `command-centre/ases.html`. It documents all 36 skills, the full pipeline, context architecture, folder structure, and hard rules in a single interactive page.

---

## Acknowledgements

Inspired by ideas from [Claude-Mem](https://github.com/thedotmack/claude-mem) (memory structuring) and [CARL](https://github.com/ChristopherKahler/carl) (runtime context control).

---

*ASES v3.2 · 36 skills · 6 agents · 3 context levels · 13 rules · 6 gates · Claude Code + Kilo Code + OpenAI Codex*
