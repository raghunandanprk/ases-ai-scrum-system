# ASES — Software Engineering Agent OS

> *The operating system layer your AI coding agent was missing.*

---

Most AI coding setups are one of two things: a clever `CLAUDE.md` with some slash commands, or a single big prompt that collapses under complexity. Neither is an operating system.

ASES is the missing layer. It sits between your intent and your AI coding agent — managing memory, routing models, enforcing roles, validating outputs, guarding commits, and maintaining a persistent, identifier-addressed record of every architectural decision across every sprint. It turns an open-ended AI session into a deterministic software delivery pipeline.

**Platform support:** Claude Code · Kilo Code · OpenAI Codex (Desktop + VS Code)

---

## What "Agent OS" Actually Means Here

An operating system manages processes, memory, I/O, and access control. ASES does the same thing — for AI agents building software.

| OS Concept | ASES Equivalent |
|---|---|
| Process scheduling | Model routing — Opus reasons, Sonnet executes, Gemini scaffolds UI, workers run in parallel |
| Memory management | Three-level context architecture — lean (always), sprint (active), global (explicit) |
| File system access control | Hook-based PO-only guard — decisions, roadmap, PRD protected at the system level |
| Inter-process communication | Typed identifier schema — DS-NNN, SP-NNN, TD-NNN bridge context across sessions |
| Kernel | `ases-hook.py` — PreToolUse hook handling injection, guards, commit gating, UI locking |
| I/O contracts | JSON+MD dual format — every output machine-readable for agents, human-readable for PO |
| Process isolation | Per-task sub-agent dispatch — each worker gets a fresh context window |
| System calls | 36 skills — the vocabulary agents use to invoke pipeline operations |

This isn't metaphor. These are architectural choices made for exactly the same reasons an OS makes them: predictability, isolation, resource efficiency, and access control.

---

## The Core Problem It Solves

When you use an LLM to build something real across multiple sessions and sprints, five things go wrong:

**Context decay.** Each new session starts cold. The agent re-reads everything, misses things, makes decisions that contradict prior sprints.

**Spec drift.** The code slowly diverges from the original design. Nobody records why.

**Scope creep.** The agent "fixes" things outside the task boundary. One well-intentioned improvement breaks three other files.

**Unchecked output.** The agent marks tasks complete without any independent verification. Bugs ship.

**No institutional memory.** Sprint 3 repeats the same architectural mistake as Sprint 1 because nothing was recorded.

ASES addresses each of these with structure, not prompting.

---

## Architecture in Three Sentences

Context is injected by hook at three levels — lean state always, sprint context during active sprints, global history only when explicitly requested by ID. Every agent has a defined role, a constrained tool surface, and a write scope enforced at runtime. Every output is schema-validated, every tradeoff logged as a typed ADR entry, and no commit reaches git without UAT approval.

---

## The Three-Level Context System

The context architecture is the OS's memory subsystem. It doesn't load everything every time — it loads exactly what's needed, at the verbosity the context window supports.

```
Level 3 — Lean Context         .ases/context.json
  Loaded:    Every session, by hook
  Contents:  8 fields — project, sprint, phase, stage, last_completed, next, blockers, prd_version
  Purpose:   Orientation — agent always knows where it is in the pipeline

Level 2 — Sprint Context       .ases/sprint_context.json
  Loaded:    Hook, during active sprint only
  Written:   /ases-sprint-gate on PASS
  Cleared:   /ases-sprint-close
  Contents:  Sprint goal, task status, open issues, relevant_decisions[] IDs
  Purpose:   Working memory for the current sprint

Level 1 — Global Context       .ases/global_context.json
  Loaded:    Explicit only — /ases-inject [IDs] or PO-facing commands
  Contents:  Full project history, identifier-addressed
  Purpose:   Long-term institutional memory, never speculatively loaded
```

### Global Context Identifier Schema

Every entry in global context has a typed identifier. Agents request entries by ID — the hook resolves them to full text. This means 200K context windows are never wasted loading history that isn't relevant to the current task.

| Prefix | Type | Example |
|---|---|---|
| `SP-NNN` | Sprint digest | `SP-001` — S1 shipped, all 14 tasks complete |
| `DS-NNN` | Architectural decision (ADR) | `DS-007` — PostgreSQL over SQLite, rationale + alternatives |
| `TD-NNN` | Tech debt item | `TD-003` — open, severity major, sprint S3 target |
| `FT-NNN` | Feature shipped | `FT-012` — F-005 shipped, 4/4 AC passed |
| `RI-NNN` | Risk item | `RI-002` — monitoring, mitigation applied |
| `CF-NNN` | Carry-forward | `CF-001` — T-007 deferred from S1 to S2 |

Surgical injection: `/ases-inject DS-003 SP-001 TD-007`  
Tag-based injection: `/ases-inject tags:M-001,performance`

---

## Model Allocation

ASES routes tasks to models by role. Every role is configurable via `system.yaml` — swap in any OpenAI-compatible endpoint.

| Role | Default Model | Responsibilities |
|---|---|---|
| **Reasoning** | Claude Opus 4.7 | Planning, architecture, critique, test design, task decomposition |
| **Execution** | Claude Sonnet 4.6 | Code generation, fixes, scaffolding, test implementation, validation |
| **UI** | Gemini 3.1 Pro | UI component specification + full Next.js/React scaffold |
| **Worker** | Sub-agent (isolated) | Per-task dev and critique in parallel, isolated context windows |
| **Decision** | Human (PO) | 6 mandatory approval gates per sprint — cannot be delegated |

Role separation is enforced, not suggested. The Execution agent cannot read `decisions.json`. The Critic cannot write code. The UI scaffold is locked after Gemini creates it — Sonnet may only touch declared `integration_points`.

---

## The Hook — `ases-hook.py`

The hook is the kernel. It runs as `PreToolUse` on every Bash, Read, and Write call — before the agent acts. Five jobs, one file.

**Job 1 — Context injection.** Builds the `<ases-state>` block from Level 3 + Level 2 context. Adapts verbosity based on remaining context window: full injection when fresh, abbreviated at moderate, minimal when depleted, warning-only when critical.

**Job 2 — PO-only file guard.** Blocks reads of `decisions.json`, `global_context.json`, `prd.md`, `roadmap.md`, and `hld.md` by any non-PO-facing command. Role-based file access control, enforced at runtime.

**Job 3 — Commit guard.** Blocks `git commit` unless `uat_report.verdict` is `APPROVED` or `CONDITIONAL` and `current_phase` is `SPRINT_SHIP`. The "commit only after UAT" rule cannot be bypassed by an agent — it's enforced at the system level, not the prompt level.

**Job 4 — UI scaffold guard.** Blocks writes to `frontend/` paths not declared in `ui_scaffold_manifest.json` integration_points. Gemini's scaffold is immutable after creation.

**Job 5 — Sub-agent config injection.** Reads `sub_agents` from `system.yaml` and injects config into the state block. Skills use this to choose between per-task sub-agent dispatch and single-session batch execution.

Platform ports: `ases-guard.ts` (Kilo Code) · `ases-guard.sh` + `ases-guard.ps1` (Codex)

---

## The Full Pipeline

### Project Start (once)

```
/ases-interview  →  /ases-prd  →  /ases-hld  →  /ases-roadmap  ⚑ PO
     →  /ases-init  →  /ases-scaffold
```

### Per Sprint

**Phase 1 — Sprint Design**
```
/ases-prd-update (optional)  →  /ases-lld  →  /ases-schema
     →  /ases-test-spec  →  /ases-sprint-gate  ⚑ PO
```

**Phase 2 — Sprint Execution**
```
/ases-analyze  →  /ases-sprint-scaffold  →  /ases-tasks

  [if UI tasks]
  /ases-ui-design  →  /ases-ui-review  →  /ases-ui-scaffold  🔒

  [primary — batch with per-task sub-agents]
  /ases-batch-exec  →  /ases-batch-critique  →  /ases-fix (per task)

  [fallback — per-task]
  /ases-validate  →  /ases-dev  →  /ases-critique  ⟳  /ases-fix

/ases-sprint-close
```

**Phase 3 — Sprint Ship**
```
/ases-test-impl  →  /ases-test-run  →  /ases-integration-test  →  /ases-system-test
                         ↑                       ↑
                    fix loop ×3            fix loop ×3

/ases-uat  ⚑ PO  →  /ases-devops  →  /ases-final-audit  ⚑ PO  →  /ases-release
```

---

## Skill Reference (36 Skills)

### Project Setup

| Skill | Agent | What it does |
|---|---|---|
| `/ases-interview` | Opus + PO | Two-pass requirements interview — product, then engineering. Produces `brief.json`. All ambiguity resolved here. |
| `/ases-prd` | Opus | PRD from brief — features, acceptance criteria, priorities, sprint allocation. Every AC must be testable. |
| `/ases-hld` | Opus | High-Level Design — modules, data flows, API boundaries, risk register. Every tradeoff → DS-NNN ADR. |
| `/ases-roadmap` | Opus | Sprint roadmap from PRD + HLD. Mandatory PO approval gate — governs entire project timeline. |
| `/ases-init` | System | Bootstraps `.ases/`, `contracts/`, `docs/`, `sprints/` structure and initial state files. Runs once. |
| `/ases-scaffold` | Opus → Sonnet | Two-step: Opus writes `scaffold_spec.json`, Sonnet executes. Creates monorepo skeleton, installs deps, verifies DB connection, runs initial graphify build. |

### Phase 1 — Sprint Design

| Skill | Agent | What it does |
|---|---|---|
| `/ases-prd-update` | Opus | Increments PRD version when scope changes between sprints. Flags invalidated HLD/LLD sections. |
| `/ases-lld` | Opus | Low-Level Design — file-level decomposition, function signatures, interfaces, `depends_on[]` arrays. The binding implementation contract. |
| `/ases-schema` | Opus | Database schema — entities, fields, indexes, relationships, migration SQL. Scoped to current sprint. |
| `/ases-test-spec` | Opus | Test cases derived exclusively from PRD acceptance criteria. Never invented. Concrete inputs + expected outputs. |
| `/ases-sprint-gate` | Opus | Five consistency checks across LLD, schema, test cases, and deps manifest. PASS writes `sprint_context.json`. Mandatory PO approval before Phase 2. |

### Phase 2 — Sprint Execution

| Skill | Agent | What it does |
|---|---|---|
| `/ases-analyze` | Opus | Diffs codebase against LLD. Graph-assisted drift detection if `graphify-out/` exists. Verdict READY gates scaffold. |
| `/ases-sprint-scaffold` | Opus → Sonnet | New module directories and migration stubs for this sprint. Applies dependency changes declared in LLD. Runs graphify update. |
| `/ases-tasks` | Opus | Decomposes LLD into task DAG with `execution_order[]`, `parallel_groups[]`, per-task plan.json + plan.md. |
| `/ases-ui-design` | Gemini | UI component specification — layout, interactions, responsive breakpoints, API integration points. |
| `/ases-ui-review` | Opus | Validates UI spec against PRD AC and HLD module boundaries. APPROVED gates scaffold. |
| `/ases-ui-scaffold` | Gemini | Complete standalone Next.js/React frontend with mock data. Locked after creation. |
| `/ases-validate` | Sonnet | Four pre-flight checks per task: input files exist, interface contracts intact, scope clear, dependencies complete. |
| `/ases-dev` | Sonnet | Implements exactly one task. Writes only to `output_files[]` from plan. Reads full instruction packet first. Pre-dev snapshot mandatory. |
| `/ases-critique` | Opus | Five lenses: spec, contract, test, security, structural (graph). Smart cap: escalate at iteration 3 if stalling, hard cap at 5. Detection only — never rewrites. |
| `/ases-fix` | Sonnet | Applies critique findings. Scope-locked to original `output_files[]`. Returns to /critique. |
| `/ases-batch-exec` | Orchestrator → Workers | Dispatches per-task `worker-dev` sub-agents. Each worker gets isolated context: own plan, LLD slice, schema slice, decisions slice. Runs graphify after completion. |
| `/ases-batch-validate` | Sonnet | Standalone batch pre-flight for all eligible tasks. |
| `/ases-batch-dev` | Sonnet | Standalone batch implementation for all validated tasks. |
| `/ases-batch-critique` | Orchestrator → Workers | Dispatches per-task `worker-critic` sub-agents. Five-lens critique in parallel. Smart cap enforced per task. |
| `/ases-sprint-close` | Opus | Graphify update → classify tasks → log tech debt → create carry-forwards → clear sprint context. Blocks if any task is `in_progress`. |

### Phase 3 — Sprint Ship

| Skill | Agent | What it does |
|---|---|---|
| `/ases-test-impl` | Sonnet | Implements test_cases.json specs as executable pytest files. Strict naming: `test_{tc_id}_{description}`. |
| `/ases-test-run` | Sonnet | Executes all tests. Regression check first. Fix loop per failing test (max 3). Gate: all critical tests must pass. |
| `/ases-integration-test` | Opus → Sonnet | Opus designs cross-module scenarios from HLD data flows. Sonnet implements and runs them. Fix loop ×3. |
| `/ases-system-test` | Opus → Sonnet | NFR scenarios with numeric thresholds — performance, security, reliability. |
| `/ases-uat` | Human (PO) | PO reviews running system against every AC item. Mandatory human gate. Rejected items → surgical re-entry. |
| `/ases-devops` | Sonnet | Git commit after UAT approval. Hook enforces — commit blocked if verdict ≠ APPROVED/CONDITIONAL. |
| `/ases-final-audit` | Opus | Six-lens sprint audit. Verdict SHIP or BLOCK. SHIP requires PO approval before release. |
| `/ases-release` | Opus | Stamps sprint complete. Writes SP-NNN, FT-NNN, TD-NNN entries to global context. Prepares next sprint. |

### Utilities

| Skill | Agent | What it does |
|---|---|---|
| `/ases-inject` | PO | Injects specific global context entries by ID or tag into the current session. |
| `/ases-graphify` | Sonnet | Builds/updates the knowledge graph via tree-sitter AST. Zero LLM cost. Auto-runs at key pipeline points. |
| `/ases-context` | Any | Displays full project state — sprint history, active decisions, open tech debt, open risks. |
| `/ases-status` | Any | Clean terminal status report — current phase, last step, next step, blockers. Under 20 lines. |
| `/ases-gc` | PO | Queries global context by ID, type, or tag without injecting into session. |
| `/ases-rollback` | PO | Restores a task to its pre-dev snapshot state with PO confirmation. |

---

## Knowledge Graph Integration (Graphify)

ASES integrates Graphify as its structural awareness layer. The graph is built from tree-sitter AST extraction — no LLM cost, no API calls, deterministic.

The graph runs automatically at four pipeline points: end of `/ases-scaffold` (initial graph), end of `/ases-sprint-scaffold` (new files), end of `/ases-batch-exec` (code changes), start of `/ases-sprint-close` (clean graph for Phase 3).

Two skills consume the graph:

`/ases-analyze` uses `GRAPH_REPORT.md` god nodes and community clusters to detect dependency drift between the LLD's declared `depends_on[]` arrays and the actual call graph.

`/ases-critique` applies Lens 5 — structural — when `graphify-out/graph.json` exists. Checks call graph connectivity for new code: is it reachable from entry points? Orphaned functions? Dead imports? Missing edges that the LLD declared?

The ADR log (`decisions.json`) with `module_refs[]` and `recall_keywords[]` per entry forms the semantic layer above the structural graph — together they give the system persistent, queryable institutional memory across sprints.

Install: `pip install graphifyy`

---

## Hard Rules

These are enforced by the hook and skill system — not by prompting.

1. JSON + MD dual format every document — agents read JSON, humans read MD
2. Execution agent writes only `output_files[]` from the task plan — no scope creep
3. Critique smart cap: 3 iterations if stalling, 5 hard max → escalate to PO
4. Critic detects only — never rewrites or redesigns
5. `scaffold_spec.json` gates execution — Reasoning writes spec first, every time
6. Execution agent never touches UI scaffold — only declared `integration_points`
7. Git commit only after UAT — hook-enforced at the system level
8. Schema validation at every gate transition
9. Every architectural tradeoff → `DS-NNN` ADR with `module_refs[]` and `recall_keywords[]`
10. Test cases from acceptance criteria only — naming: `test_{tc_id_lowercase}_{description}`
11. `/ases-test-run` required before integration tests — regression check mandatory
12. Phase 3 fix loop — max 3 iterations per failing test, then escalate
13. Sprint-close blocks if any task has `status: in_progress`

---

## Human Gates (6 Per Sprint)

ASES stops and waits. These cannot be bypassed by an agent.

| Gate | Trigger | What's blocked |
|---|---|---|
| 1 | After `/ases-roadmap` | `/ases-init` — entire project |
| 2 | After `/ases-sprint-gate` PASS | `/ases-analyze` — Phase 2 |
| 3 | Any `ESCALATE` verdict | Next dev cycle |
| 4 | `/ases-uat` PO review | `/ases-devops` — git commit |
| 5 | After `/ases-final-audit` SHIP | `/ases-release` |
| 6 | Any `BLOCK` verdict | Directed surgical re-entry |

---

## Folder Structure

```
your-project/
│
├── .ases/                          ← System state (hook-managed)
│   ├── context.json + .md          ← Level 3: lean, always loaded
│   ├── sprint_context.json + .md   ← Level 2: sprint-scoped
│   ├── global_context.json + .md   ← Level 1: explicit only, PO-controlled
│   ├── decisions.json + .md        ← ADR log, PO-controlled
│   └── .audit.log                  ← System audit trail
│
├── .claude/                        ← Claude Code platform
│   ├── hooks/ases-hook.py          ← 5-job kernel hook
│   ├── skills/ases-*/SKILL.md      ← 36 skills
│   ├── agents/                     ← 6 agent definitions
│   ├── commands/                   ← Utility commands
│   └── system.yaml                 ← Model + sub-agent config
│
├── .kilo/                          ← Kilo Code platform
│   ├── plugin/ases-guard.ts        ← TypeScript hook port
│   ├── skills/ agents/ rules/
│   └── system.yaml
│
├── .codex/                         ← OpenAI Codex (Desktop / VS Code)
│   ├── hooks/ases-guard.sh         ← Bash hook port
│   ├── hooks/ases-guard.ps1        ← PowerShell hook port (Windows)
│   ├── hooks.json
│   ├── config.toml
│   └── skills/
│
├── .github/agents/                 ← VS Code / Codex agent definitions (.agent.md)
│
├── format/                         ← JSON schemas + MD templates (excluded from scan)
├── docs/                           ← PO-facing documents (excluded from scan)
├── contracts/                      ← Agent JSON contracts (excluded from scan)
│
├── sprints/
│   └── S1/
│       ├── design/                 ← Phase 1: lld, schema, test_cases, sprint_gate
│       ├── execution/              ← Phase 2: analysis, tasks, snapshots/, tasks/
│       └── ship/                   ← Phase 3: test_suite, uat, audit, release
│
├── backend/                        ← FastAPI / Python
│   └── tests/{unit,integration,system}/
├── frontend/                       ← Next.js / React (locked after ui-scaffold)
│
├── graphify-out/                   ← Knowledge graph (excluded, auto-built)
│   ├── graph.json
│   ├── GRAPH_REPORT.md
│   └── graph.html
│
├── CLAUDE.md                       ← Claude Code always-loaded config
├── AGENTS.md                       ← Kilo Code + Codex config
└── command-centre/ases.html        ← Interactive visual reference
```

---

## Quick Start

### Claude Code

```bash
# Copy ASES into your project
cp -r ases-ai-scrum-system/.claude     your-project/
cp -r ases-ai-scrum-system/format      your-project/
cp    ases-ai-scrum-system/CLAUDE.md   your-project/
cp    ases-ai-scrum-system/.claudeignore your-project/

cd your-project && claude
/ases-interview
```

### Kilo Code

```bash
cp -r ases-ai-scrum-system/.kilo       your-project/
cp -r ases-ai-scrum-system/format      your-project/
cp    ases-ai-scrum-system/AGENTS.md   your-project/
cp    ases-ai-scrum-system/.kilocodeignore your-project/

# Open in Kilo Code
/ases-interview
```

### OpenAI Codex (Desktop / VS Code)

```bash
cp -r ases-ai-scrum-system/.codex          your-project/
cp -r ases-ai-scrum-system/.github         your-project/
cp -r ases-ai-scrum-system/format          your-project/
cp    ases-ai-scrum-system/AGENTS.md       your-project/

# Open in Codex, trust the project when prompted
/ases-interview
```

All platforms share `.ases/`, `format/`, `contracts/`, `docs/`, and `sprints/`. The skills, agents, and `system.yaml` are identical across platforms — only the hook mechanism and platform config differ.

---

## Platform Support

| Platform | Config | Hook | Sub-Agent Tool |
|---|---|---|---|
| Claude Code | `CLAUDE.md` + `.claude/` | `ases-hook.py` (Python) | `Agent` tool |
| Kilo Code | `AGENTS.md` + `.kilo/` | `ases-guard.ts` (TypeScript) | `new_task` tool |
| OpenAI Codex | `AGENTS.md` + `.codex/` + `.github/agents/` | `ases-guard.sh` / `ases-guard.ps1` | `runSubagent` tool |

---

## Requirements

- **Claude Code**, **Kilo Code**, or **OpenAI Codex** — ASES runs inside any of these
- **Git** — enforced at release gate
- **Python 3.11+** — for `ases-hook.py`; no external dependencies (stdlib only)
- **Graphify** (optional) — `pip install graphifyy` for structural awareness features
- **Gemini access** (optional) — required for UI scaffold path only
- **PostgreSQL** (optional) — default DB stack; swap to any backend via `system.yaml`
- **jq** (Codex / Bash hook, optional) — for shell hook JSON parsing on non-Windows

---

## Who This Is For

**Developers building real, multi-sprint software projects with AI coding agents** who have hit the wall where unstructured AI sessions produce inconsistent, hard-to-maintain results.

Specifically, you want:
- Decisions recorded with rationale, not just made
- The agent to critique its own work before marking it done
- A human checkpoint before anything reaches production
- Exact knowledge of what context the agent has at any point
- Code that doesn't drift from the original design across sprints

**Not for:** one-off scripts, quick experiments, single-session tasks. ASES has setup overhead. It pays for itself on projects that span more than one sprint.

---

## Acknowledgements

Inspired by [Claude-Mem](https://github.com/thedotmack/claude-mem) (memory structuring patterns) and [CARL](https://github.com/ChristopherKahler/carl) (runtime context control via hooks).

---

*ASES v3.2 · Software Engineering Agent OS · 36 skills · 6 agents · 3 context levels · 13 rules · 6 gates*  
*Claude Code + Kilo Code + OpenAI Codex · Opus 4.7 · Sonnet 4.6 · Gemini 3.1 Pro · Model-agnostic via system.yaml*
