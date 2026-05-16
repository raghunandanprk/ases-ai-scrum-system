---
name: ases-graphify
description: >
  ASES Utility — Build or update the project knowledge graph using tree-sitter AST extraction.
  Invoke with /ases-graphify to rebuild. Also runs automatically as a sub-step of /ases-scaffold
  and /ases-sprint-scaffold. Produces graphify-out/graph.json and GRAPH_REPORT.md used by
  /ases-analyze and /ases-critique for structural awareness. AST-only — no LLM cost.
allowed-tools: Read, Write, Bash(graphify:*)
argument-hint: "(no arguments)"
---

# ASES `/ases-graphify`
**Agent:** Execution (Sonnet) · **Scope:** Project · **Cost:** Zero (local AST only)

## When to Run
- **Auto:** End of `/ases-scaffold` (first full graph), end of `/ases-sprint-scaffold` (new files),
  end of `/ases-batch-exec` (code changes), start of `/ases-sprint-close` (clean graph for Phase 3)
- **Manual:** Anytime — `/ases-graphify`

## Process
1. Run AST-only graph build/update:
   ```bash
   graphify update .
   ```
2. Verify output exists:
   ```bash
   ls graphify-out/graph.json graphify-out/GRAPH_REPORT.md
   ```
3. If first run (no prior graph.json) and `graphify update` fails, run full build:
   ```bash
   graphify update .
   ```
4. Log result to stdout:
   ```
   [ASES-GRAPHIFY] Graph updated — N nodes, M edges
   ```

## Output
```
graphify-out/graph.json        ← persistent graph structure
graphify-out/GRAPH_REPORT.md   ← god nodes, communities, dependencies
graphify-out/graph.html        ← interactive visualization
```

## Context Bracket Behavior
- **FRESH/MODERATE:** Full graph build, report available to downstream skills
- **DEPLETED/CRITICAL:** Skip graph — not worth the context cost

## Notes
- `graphify update` uses tree-sitter only (Pass 1) — deterministic, free, local
- SHA256 cache means only changed files are re-parsed
- Graph is excluded from auto-scan via `.claudeignore` / `.kilocodeignore`
- Skills that consume the graph (`analyze`, `critique`) treat it as optional input
