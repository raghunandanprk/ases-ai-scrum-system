---
name: ases-sprint-scaffold
description: >
  ASES Sprint Execution — Create new structural files for the current sprint. Invoke with
  /ases-sprint-scaffold [sprint-id] after /ases-analyze READY. TWO-STEP: Opus identifies
  new structure needed (Step A), then Claude Sonnet creates it (Step B). Sonnet only creates
  files explicitly listed by Opus. Whitelisted types only. Updates scaffold manifest.
allowed-tools: Read, Write, Bash(mkdir:*), Bash(find:*), Bash(npm:*), Bash(npx:*), Bash(python3:*), Bash(psql:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-sprint-scaffold [sprint-id]`
**Agent:** Architect (Opus) identifies → Developer (Claude Sonnet) creates

---

## Step A — Opus Identifies New Structure + Dependency Changes

Read `sprints/$ARGUMENTS/design/lld.json` and `contracts/scaffold.json`.

Diff: which files in lld.json do NOT exist in scaffold.json?
List only:
- New module directories
- `__init__.py` stubs (empty body)
- Migration stub files (e.g. `backend/db/migrations/NNNN_<name>.sql` placeholders —
  empty SQL bodies, real DDL is filled by /ases-dev tasks)
- New config entries

**Dependency changes (DS-014 — dependency drift policy):**
A sprint may add, remove, or bump dependencies if and only if the LLD declares them
in `lld.new_dependencies[]`, `lld.removed_dependencies[]`, or `lld.bumped_dependencies[]`.
Each entry MUST include rationale (e.g. *"required for T-007 SSE broker"*,
*"CVE-2026-XXXX"*). No silent additions.

Copy these dependency entries verbatim into:
```jsonc
"dependency_changes": {
  "backend": {
    "add":    [ { "name": "...", "version": "...", "reason": "..." } ],
    "remove": [ { "name": "...", "reason": "..." } ],
    "bump":   [ { "name": "...", "from_version": "...", "to_version": "...", "reason": "..." } ]
  },
  "frontend": { /* same shape */ }
}
```

Write `sprints/$ARGUMENTS/design/scaffold_spec.json` with the exact file list and
dependency_changes block. This file gates Step B — Sonnet does not start without it.

---

## Step B — Sonnet Creates Structure + Applies Dependency Changes

**Pre-check:** Read `sprints/$ARGUMENTS/design/scaffold_spec.json`.
If it does not exist → STOP. Output: "Sprint scaffold_spec.json missing — Opus must complete Step A first."

**Permitted file types (whitelist):**
- `__init__.py` — empty body: `# {module name} module\n` only
- `*.py` migration stubs — class definition + `pass` only
- `*.sql` migration stubs in `backend/db/migrations/` — header comment + empty body
- New directories via `mkdir -p`
- Config entries appended to existing config files only

**Permitted manifest edits (DS-014, only if listed in `dependency_changes`):**
- `backend/requirements.txt` — append/remove/bump per spec
- `frontend/package.json` `dependencies` and `devDependencies` — append/remove/bump per spec
- ANY other file edit in this step → forbidden

**Forbidden:** Any file with business logic, imports of project modules, or function bodies.

Create only files listed in `scaffold_spec.files_to_create[]`. Apply only dep changes
in `scaffold_spec.dependency_changes`.

After applying dep manifest edits, install:
```bash
backend/.venv/bin/pip install -r backend/requirements.txt
cd frontend && npm install
```
Capture pip and npm output for the manifest update in Step C.

---

## Step C — Update Scaffold Manifest

Add new files to `contracts/scaffold.json` with timestamps and empty hashes.

### Step B.5 — Apply Migrations
If any new migration files exist in `backend/db/migrations/` (listed in
`scaffold_spec.files_to_create[]`) AND they have content (non-empty body):
1. Apply each in filename order:
   ```bash
   psql -U <db.app_role> -d <db.name> -f backend/db/migrations/NNNN_<name>.sql
   ```
2. Record results in Step C manifest under `migrations_applied[]`:
   ```json
   { "file": "0002_users.sql", "result": "applied", "rows_affected": 0 }
   ```
3. If any migration fails → **STOP** — report error, do not continue to `/ases-tasks`

> Empty stubs (header only, no DDL) are skipped — they will be filled by
> `/ases-dev` tasks and applied mid-sprint via Step 4.5 in `/ases-dev`.

If dependency_changes were applied, append a `sprint_<ARGUMENTS>` block:
```jsonc
"sprint_<ARGUMENTS>": {
  "added_packages":   [ { "side": "backend", "name": "...", "version": "..." } ],
  "removed_packages": [ { "side": "backend", "name": "..." } ],
  "bumped_packages":  [ { "side": "frontend", "name": "...", "from": "...", "to": "..." } ],
  "pip_log_excerpt":  "<last 20 lines of pip install output>",
  "npm_log_excerpt":  "<last 20 lines of npm install output>"
}
```

Update `docs/scaffold.md`.

## Step B.6 — Update Knowledge Graph
Run `graphify update .` to capture new files in the project graph.
If context bracket is DEPLETED/CRITICAL, skip this step.

## Next Step
→ `/ases-tasks $ARGUMENTS`
