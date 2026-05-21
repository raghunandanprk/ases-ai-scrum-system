---
name: ases-scaffold
description: >
  ASES Phase 1 — Build the runnable monorepo skeleton (backend + frontend + database).
  Invoke with /ases-scaffold after /ases-init. TWO-STEP: Opus writes scaffold_spec.json
  first (Step A), then Claude Sonnet executes (Step B). Sonnet does NOT start until
  scaffold_spec.json exists. Step B has four sub-steps: B.1 DB bootstrap, B.2 backend
  venv + pip install, B.3 DB connection verify, B.4 frontend npm install + shadcn init.
  Step C runs verify_cmd; Step D writes scaffold.json manifest.
allowed-tools: Read, Write, Bash(mkdir:*), Bash(npm:*), Bash(npx:*), Bash(python3:*), Bash(find:*), Bash(psql:*)
---

# ASES `/ases-scaffold`
**Agent:** Architect (Opus) writes spec → Developer (Claude Sonnet) executes

---

## Step A — Opus Writes Scaffold Spec

Read `contracts/hld.json`, `contracts/brief.json`, `contracts/roadmap.json`,
`.ases/decisions.json`.

Produce `contracts/scaffold_spec.json` — exact instructions for Sonnet.
Every file must have explicit `path`, `type`, and `content`.
No ambiguity — Sonnet receives complete machine-readable instructions.

### Required top-level fields in `scaffold_spec.json`

```jsonc
{
  "topology": "monorepo",                         // locked: monorepo per DS-011
  "tech_stack": {
    "backend": "fastapi",
    "frontend": "nextjs",
    "db": "postgresql",
    "python_version": "3.12",
    "node_version": ">=20"
  },

  "db": {
    "name": "<project_db>",                       // app DB name
    "app_role": "<project_app>",                  // app login role
    "host": "localhost",
    "port": 5432,
    "extensions": ["pgcrypto"],                   // CREATE EXTENSION list
    "bootstrap_sql_path": "backend/db/bootstrap.sql"
  },

  "backend": {
    "venv_path": "backend/.venv",
    "dependencies": [                             // EXACT pins per DS-014
      { "name": "fastapi", "version": "0.115.4" },
      { "name": "uvicorn", "version": "0.32.0" },
      { "name": "sqlalchemy", "version": "2.0.36" },
      { "name": "psycopg[binary]", "version": "3.2.3" }
      // ...
    ],
    "env_schema": [                               // drives backend/.env.example contents
      { "key": "DATABASE_URL", "description": "postgresql://<app_role>:...@localhost:5432/<project_db>", "required": true },
      { "key": "JWT_SECRET", "description": "32+ char random string", "required": true }
      // ...
    ],
    "verify_cmd": "backend/.venv/bin/python -c \"import fastapi, sqlalchemy, psycopg; psycopg.connect('${DATABASE_URL}').close()\"",
    "expected_verify_output": ""
  },

  "frontend": {
    "package_manager": "npm",
    "dependencies": [                             // package.json dependencies, exact pins
      { "name": "next", "version": "15.0.3" },
      { "name": "react", "version": "19.0.0" },
      { "name": "tailwindcss", "version": "3.4.14" }
      // ...
    ],
    "shadcn_components": [                        // pre-installed shadcn primitives
      "button", "card", "dialog", "input", "label", "tabs", "toast"
    ],
    "verify_cmd": "cd frontend && npx tsc --noEmit",
    "expected_verify_output": ""
  },

  "files_to_create": [
    { "path": "backend/pyproject.toml", "type": "toml", "content": "..." },
    { "path": "backend/requirements.txt", "type": "requirements", "content": "..." },
    { "path": "backend/.env.example", "type": "env", "content": "..." },
    { "path": "frontend/package.json", "type": "json", "content": "..." },
    { "path": ".gitignore", "type": "gitignore", "content": "..." }
    // ...
  ],

  "packages_to_install": []                       // legacy field — leave empty,
                                                  // backend/frontend dep lists drive install
}
```

Schema: `format/json/scaffold_spec.schema.json`

---

## Step B — Sonnet Executes (only after scaffold_spec.json exists)

**Pre-check:** Read `contracts/scaffold_spec.json`.
If it does not exist → STOP. Output: "scaffold_spec.json missing — Opus must complete Step A first."

Read `contracts/scaffold_spec.json` completely before creating any file.

**Permitted file types (whitelist — nothing else):**
- `*.toml` `*.json` `*.ini` `*.cfg` `*.yaml` `*.yml` — config files
- `.gitignore` `.env.example` `.claudeignore` — project root or backend root
- `__init__.py` — empty body only: `# module init\n`
- `index.ts` — type exports only: `export * from './types'`
- `README.md` — headings and placeholder text only
- `requirements.txt` `package.json` `pyproject.toml` — dependency manifests
- `*.sql` — ONLY `backend/db/bootstrap.sql` (DB role+database creation)
  and `backend/db/migrations/0001_baseline.sql` (placeholder header only at
  scaffold time; real schema comes from sprint LLD)

**Any file not matching this whitelist → do not create → flag in output.**

Create each file in `scaffold_spec.files_to_create[]` exactly as specified.

---

### Step B.1 — Database Bootstrap (one-time, halts for PO action on first run)

Pre-condition: `scaffold_spec.json.db.*` is populated.

1. **If `backend/db/bootstrap.sql` does NOT yet exist:**
   Generate it from `scaffold_spec.db.*` with these literal SQL statements
   (Sonnet writes verbatim, do NOT execute):

   ```sql
   -- Generated by /ases-scaffold Step B.1.
   -- Run once as the postgres superuser:
   --   psql -U postgres -f backend/db/bootstrap.sql
   --
   -- BEFORE RUNNING: replace <CHANGE_ME> below with a real password,
   -- and put the same password in backend/.env under DATABASE_URL.

   CREATE DATABASE <db.name>;
   CREATE ROLE <db.app_role> WITH LOGIN PASSWORD '<CHANGE_ME>';
   GRANT ALL PRIVILEGES ON DATABASE <db.name> TO <db.app_role>;

   \c <db.name>

   -- Extensions (one CREATE per <db.extensions[]> entry):
   CREATE EXTENSION IF NOT EXISTS pgcrypto;

   GRANT ALL ON SCHEMA public TO <db.app_role>;
   ```

   Output to PO:
   ```
   I have written backend/db/bootstrap.sql.
     1. Edit it: replace <CHANGE_ME> with a real password.
     2. Set DATABASE_URL in backend/.env to use the same password.
     3. Run as postgres superuser:
          psql -U postgres -f backend/db/bootstrap.sql
     4. Re-run /ases-scaffold to continue.
   ```
   STOP scaffold here. Do NOT proceed to Step B.2.

2. **If `backend/db/bootstrap.sql` already exists:**
   Skip generation. Continue to Step B.2 (DB connection is verified later in B.3,
   after the venv exists and `psycopg` is installed).

---

### Step B.2 — Backend venv + pip install

Pre-condition: `backend/requirements.txt` and `backend/.env.example` exist
(written in this scaffold pass via `files_to_create[]`).

1. **Verify `backend/.env` exists.** If missing → STOP. Output:
   ```
   backend/.env not found.
     1. Copy backend/.env.example to backend/.env.
     2. Fill DATABASE_URL, JWT_SECRET, and any other required keys
        per env_schema in scaffold_spec.json.
     3. Re-run /ases-scaffold.
   ```
2. **Create venv:**
   ```bash
   python3 -m venv backend/.venv
   ```
   (Windows: same command — venv layout differs but creation command is identical.)
3. **Install dependencies:**
   ```bash
   backend/.venv/bin/pip install --upgrade pip
   backend/.venv/bin/pip install -r backend/requirements.txt
   ```
   On Windows substitute `backend/.venv/Scripts/pip`.
4. **Capture pip-installed package list** (pip freeze output) for the manifest in Step D.

---

### Step B.3 — Database Connection Verify

Pre-condition: backend venv exists, `psycopg` is installed (Step B.2 done),
`backend/.env` exists with `DATABASE_URL` set.

1. Read `DATABASE_URL` from `backend/.env`.
2. Run a connection test:
   ```bash
   backend/.venv/bin/python -c "import psycopg, os; psycopg.connect(os.environ['DATABASE_URL']).close(); print('db_ok')"
   ```
   (load `.env` into the env first — use the project's standard env loader, or
   `set -a; source backend/.env; set +a` in bash.)
3. **If the connection fails → STOP. Output:**
   ```
   Cannot connect to the application database.
     - Verify backend/db/bootstrap.sql was run as the postgres superuser.
     - Verify DATABASE_URL in backend/.env uses the password set in step 1 above.
     - Verify the postgres server is running on the host/port in DATABASE_URL.
   Then re-run /ases-scaffold.
   ```
4. **If it passes**, log success — record `db.bootstrap_verified=true` for Step D.

---

### Step B.4 — Frontend npm install + shadcn init

Pre-condition: `frontend/package.json` exists.

1. **Install dependencies:**
   ```bash
   cd frontend && npm install
   ```
2. **Initialize shadcn/ui** (skip if `frontend/components.json` already exists):
   ```bash
   cd frontend && npx shadcn@latest init --yes
   ```
3. **Pre-install shadcn components** listed in `scaffold_spec.frontend.shadcn_components[]`:
   ```bash
   cd frontend && npx shadcn@latest add <component> --yes
   ```
   (one invocation per component, or batched if shadcn supports it)
4. **Capture installed npm package list** for the manifest in Step D.

---

## Step C — Verify and Report

Run BOTH verify_cmds from `scaffold_spec.json`:

```bash
# Backend verify (uses venv from B.2, db from B.3)
<scaffold_spec.backend.verify_cmd>

# Frontend verify
<scaffold_spec.frontend.verify_cmd>
```

Report the actual output for each. Compare against
`expected_verify_output` (when set; many verify commands legitimately produce
empty output on success).

If either fails → list the discrepancy. Do NOT attempt to fix — report only.
Both must pass for scaffold to be considered complete.

---

## Step D — Write Scaffold Manifest

Write `contracts/scaffold.json` — full record:

```jsonc
{
  "created_at": "<ISO-8601>",
  "topology": "monorepo",
  "tech_stack": {
    "backend": "fastapi",
    "frontend": "nextjs",
    "db": "postgresql",
    "python_version": "3.12",
    "node_version": ">=20"
  },
  "db": {
    "name": "<project_db>",
    "app_role": "<project_app>",
    "host": "localhost",
    "port": 5432,
    "extensions": ["pgcrypto"],
    "bootstrap_sql_path": "backend/db/bootstrap.sql",
    "bootstrap_verified": true
  },
  "backend": {
    "venv_path": "backend/.venv",
    "installed_packages": [
      { "name": "fastapi", "version": "0.115.4" }
      // ... full pip freeze output
    ],
    "verify_cmd": "...",
    "verify_output": "<actual output>",
    "verify_passed": true
  },
  "frontend": {
    "package_manager": "npm",
    "shadcn_initialized": true,
    "shadcn_components_installed": ["button", "card", "..."],
    "installed_packages": [
      { "name": "next", "version": "15.0.3" }
      // ... full npm list --depth=0 output
    ],
    "verify_cmd": "...",
    "verify_output": "<actual output>",
    "verify_passed": true
  },
  "files": [
    { "path": "backend/pyproject.toml", "type": "toml", "hash": "<sha256>" }
    // ... every file Sonnet created
  ]
}
```

Write `docs/scaffold.md` — human-readable summary for PO.

## Step E — Build Knowledge Graph
Run `graphify update .` to build the initial project graph from the scaffolded codebase.
If context bracket is DEPLETED/CRITICAL, skip this step.

## Next Step
→ Sprint cycle begins: `/ases-prd-update [sprint-id]` (optional) then `/ases-lld S1`
