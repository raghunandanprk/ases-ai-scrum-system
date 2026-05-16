# ASES Hard Rules

These rules are non-negotiable. Every ASES agent must follow them at all times.

## Output Format
1. JSON-only outputs between all pipeline stages
2. Every document has two files: `name.json` (agent) + `name.md` (human)

## Scope Isolation
3. File-level isolation for every `/ases-dev` and `/ases-fix` — write only to `output_files[]` from task plan
4. Execution agent never touches UI scaffold — only declared `integration_points`

## Critique Loop
5. Critique loop mandatory — smart cap: 3 iterations if stalling, 5 max, then escalate to PO

## Role Separation
6. No agent role overlap — Critic detects only, Execution agent implements only

## Gates
7. Schema validation at every gate transition
8. Git commit only after UAT approval — `ases-guard.ts` plugin enforces this

## Documentation
9. Every architectural tradeoff → ADR entry in `decisions.json` with typed ID (DS-NNN)

## Testing
10. Test cases derived from PRD `acceptance_criteria` — never invented
11. Test execution (`/ases-test-run`) required before integration tests
12. Phase 3 fix loop: max 3 iterations per failing test, then escalate

## Sprint Lifecycle
13. Sprint-close blocks if any task has `status: in_progress`
