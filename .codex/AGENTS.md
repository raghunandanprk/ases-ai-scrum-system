# ASES v3.2 — Codex Platform Instructions

<!-- ASES-MANAGED: Do not remove -->
## Context Integration
Obey all `<ases-state>` blocks injected by `ases-guard.sh`. They are live project state.
<!-- END ASES-MANAGED -->

## Platform: OpenAI Codex (Desktop / VS Code)

This file supplements the root `AGENTS.md` with Codex-specific instructions.

### Skill Invocation

ASES skills are stored in `.codex/skills/ases-*/SKILL.md`. When the user invokes
a slash command (e.g., `/ases-analyze S1`), read the corresponding skill file and
execute its instructions.

### Sub-Agent Dispatch

For batch execution (`/ases-batch-exec`, `/ases-batch-critique`), use the
`runSubagent` tool to dispatch isolated worker agents:

- **Worker Dev:** agent `worker-dev` — defined in `.github/agents/worker-dev.agent.md`
- **Worker Critic:** agent `worker-critic` — defined in `.github/agents/worker-critic.agent.md`

These workers have `user-invocable: false` — they are only invoked via `runSubagent`.

### Guard Hooks

The `ases-guard.sh` hook (registered in `.codex/hooks.json`) enforces:
1. PO-only file access control
2. Git commit guard (UAT required)
3. UI scaffold lock
4. Context injection

### File Exclusions

Codex uses `.gitignore` for file exclusions. The following are additionally excluded
from auto-scanning (access only via explicit skill reads):
- `/format/` — ASES schemas and templates
- `/contracts/` — machine-readable JSON contracts
- `/docs/brief.md`, `/docs/scaffold.md` — PO documents
- `/graphify-out/` — knowledge graph output
- `.ases/global_context.json` — use `/ases-inject [ID]` for surgical access
