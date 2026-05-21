---
name: ases-ui-scaffold
description: >
  ASES Sprint Execution UI Track — Gemini builds the complete standalone Next.js/React
  scaffold after UI review approval. Invoke with /ases-ui-scaffold [sprint-id] after
  /ases-ui-review APPROVED. Produces complete runnable frontend with mock data. Zero backend
  calls, zero auth logic. Locked after creation — GLM may only touch integration_points.
allowed-tools: Read, Write, Bash(npm:*), Bash(mkdir:*)
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-ui-scaffold [sprint-id]`
**Agent:** UI Designer (Gemini) · **Scope:** Sprint · **Runs after:** ui_review.APPROVED

## Input
Read `sprints/$ARGUMENTS/execution/ui_spec.json` (approved), `sprints/$ARGUMENTS/execution/ui_review.json`

## Process
1. Build the complete Next.js/React project DIRECTLY under `frontend/` (no
   intermediate `/ui/` folder, no template-then-translate step). The frontend
   package was already initialized by `/ases-scaffold` Step B.4 (npm install +
   shadcn init); this step fills in `frontend/src/`.
2. Implement all components from ui_spec exactly. Use Tailwind + shadcn/ui
   primitives already installed by `/ases-scaffold`.
3. Create the mocks module at `frontend/src/lib/mocks.ts` (single file).
4. Create the integration boundary at `frontend/src/lib/api.ts` — every
   component/hook imports its data from `api.ts`. Initial implementation of each
   exported function in `api.ts` simply returns data from `mocks.ts`. This is
   the ONLY file Sonnet will edit later (during /ases-dev) to swap mock returns
   for real `fetch()` calls against the FastAPI backend.
5. Declare all `integration_points` in the manifest — every exported function in
   `frontend/src/lib/api.ts` is an integration_point. No other file should
   contain integration_points; if a component needs backend data, it goes
   through `api.ts`.
6. Verify the project runs standalone: `cd frontend && npm run dev`.

## Rules
- ZERO direct backend API calls in components/hooks — they call functions from
  `frontend/src/lib/api.ts`, which returns mock data initially
- ZERO auth/session logic in components — `api.ts` may have a placeholder
  `getCurrentUser()` returning a mock; real JWT wiring comes later via /ases-dev
- ZERO env var reads in components — `api.ts` may read `NEXT_PUBLIC_API_BASE`
  later, but in the scaffold pass it's hardcoded
- Every backend-touching exported function in `api.ts` MUST be declared as an
  `integration_point` in the manifest
- Multi-device responsive: implement mobile / tablet / desktop layouts per the
  ui_spec breakpoints (DS-010)

## 🔒 Post-Scaffold Lock
The frontend scaffold is **LOCKED** after this step.
Sonnet may ONLY touch declared `integration_points` (i.e. function bodies in
`frontend/src/lib/api.ts`) and may delete `frontend/src/lib/mocks.ts` once
all functions in `api.ts` have been swapped to real backend calls.
Any structural change (new component, new route, layout change) requires a new
ui-design → ui-review → ui-scaffold cycle.

## Output
```
frontend/                                                 ← complete runnable Next.js project
  src/
    app/                                                  ← App Router routes
    components/
    lib/
      api.ts                                              ← single integration boundary
      mocks.ts                                            ← mock data, deleted after integration
    styles/
sprints/$ARGUMENTS/execution/ui_scaffold_manifest.json    ← schema: format/json/ui_scaffold_manifest.schema.json
sprints/$ARGUMENTS/execution/ui_scaffold_manifest.md
```

## Next Step
→ Begin execution loop with `/ases-validate [first-task-id] $ARGUMENTS`
