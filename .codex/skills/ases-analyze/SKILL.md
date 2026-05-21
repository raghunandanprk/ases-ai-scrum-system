---
name: ases-analyze
description: >
  ASES Sprint Execution — Analyze codebase against sprint requirements before tasks run.
  Invoke with /ases-analyze [sprint-id] after /ases-sprint-gate PASS. Diffs deps_manifest
  against actual codebase, identifies blocking and non-blocking gaps. BLOCKED verdict
  prevents /ases-tasks from running. Fix gaps then re-run.
allowed-tools: Read, Write, Bash(ls:*), Bash(find:*), Bash(cat:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-analyze [sprint-id]`
**Agent:** Architect (Opus) · **Scope:** Sprint · **Gate: verdict=READY**

## Input
Read `sprints/$ARGUMENTS/design/deps_manifest.json`,
`sprints/$ARGUMENTS/design/lld.json`,
`.ases/context.json` (sprint_history),
`contracts/scaffold.json`

Optional (if exists): `graphify-out/GRAPH_REPORT.md`, `graphify-out/graph.json`

Scan codebase:
```bash
!`find . -name "*.py" -o -name "*.ts" -o -name "*.tsx" | head -50`
!`ls -la`
```

## Process
1. Diff `deps_manifest.packages` against installed packages
2. Diff `lld.json files[]` against existing codebase
3. Check `env_vars` against `.env.example`
4. Detect drift from previous sprints
5. Classify: blocking (prevents dev) vs non-blocking
6. **Graph-assisted** (if `graphify-out/GRAPH_REPORT.md` exists):
   - Use god nodes and community clusters to prioritize analysis
   - Cross-reference graph edges against LLD `depends_on[]` for dependency drift
   - Note in output: `"graph_assisted": true`

## Rules
- BLOCKED if any `blocking_gap` exists → `/ases-tasks` must not run
- Resolution instructions must be specific + actionable

## Output
```
sprints/$ARGUMENTS/execution/analysis.json   ← schema: format/json/analysis.schema.json
sprints/$ARGUMENTS/execution/analysis.md
```

READY → `/ases-sprint-scaffold $ARGUMENTS`
BLOCKED → present `blocking_gaps` to PO with resolutions → re-run after fixes
