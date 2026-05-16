---
name: ases-test-spec
description: >
  ASES Sprint Design — Generate test case specifications from PRD acceptance criteria and
  LLD interfaces. Invoke with /ases-test-spec [sprint-id] after /ases-schema completes.
  Specs only — no implementation code. GLM implements in Phase 3. CRITICAL: every test case
  must link to an ac_ref — never invented.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-test-spec [sprint-id]`
**Agent:** Tester (Opus) · **Scope:** Sprint

## Input
Read `contracts/prd.json` (acceptance_criteria for this sprint's features),
`sprints/$ARGUMENTS/design/lld.json` (interfaces[]),
`sprints/$ARGUMENTS/design/schema.json`

## Process
1. For each AC in this sprint's features → write ≥1 test case
2. For each lld file interface → write unit tests (happy path + edge cases)
3. Identify integration test cases from `hld.data_flow`
4. Assign priority — AC-linked tests are `critical`
5. Specify exact `inputs` + `expected_output` — must be deterministic

## Rules
- Every test case MUST link to `ac_ref` — no invented cases
- `inputs` and `expected_output` must be concrete values
- `type: edge` cases must be explicit
- `framework` specified per test case

## Output
```
sprints/$ARGUMENTS/design/test_cases.json   ← schema: format/json/test_cases.schema.json
sprints/$ARGUMENTS/design/test_cases.md
```

## Next Step
→ `/ases-sprint-gate $ARGUMENTS`
