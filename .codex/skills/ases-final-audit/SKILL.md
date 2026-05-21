---
name: ases-final-audit
description: >
  ASES Sprint Ship — Six-lens comprehensive audit of the entire sprint output. Invoke with
  /ases-final-audit [sprint-id] after /ases-devops. Reads unit tests, integration tests,
  system tests, UAT, spec conformance, risk review. BLOCK triggers surgical re-entry.
  SHIP or CONDITIONAL_SHIP requires PO approval before /ases-release.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-final-audit [sprint-id]`
**Agent:** Critic (Opus) · **Scope:** Sprint · **Gate: verdict!=BLOCK**

## Input
Read all sprint ship outputs for `$ARGUMENTS`:
`test_suite.json`, `integration_scenarios.json`, `system_test_report.json`,
`uat_report.json`, `lld.json`, `contracts/hld.json` (risks[]), `.ases/decisions.json`

## Six Lenses

1. **Test Coverage** — all `test_case_refs` from sprint_close covered? critical AC with no test?
2. **Integration Integrity** — all scenarios passed? module contract violations?
3. **System Test** — critical NFR failures? thresholds met?
4. **UAT Alignment** — conditional notes → minor findings / tech debt
5. **Spec Conformance** — built system matches `lld.json` interfaces? undeclared drift?
6. **Risk Review** — critical/medium HLD risks encountered? mitigations applied? new risks?

## Severity Tiers
- `critical` → **BLOCK** — must fix before release
- `major` → **CONDITIONAL_SHIP** — tech debt, PO decides
- `minor | warning` → **SHIP** — logged, no block

## Surgical Re-entry Routes
| Finding | Re-entry |
|---|---|
| test_coverage critical | `/ases-test-impl` re-run |
| integration violation | execution loop for affected tasks |
| spec drift | `/ases-fix` targeted |
| upstream PRD issue | `/ases-prd-update` next sprint |

## Output
```
sprints/$ARGUMENTS/ship/final_audit.json   ← schema: format/json/final_audit.schema.json
sprints/$ARGUMENTS/ship/final_audit.md     ← template: format/markdown/final_audit.template.md
```

## ⚠ Human Gate
BLOCK → direct PO to surgical re-entry
SHIP | CONDITIONAL_SHIP → present `final_audit.md` → await PO approval → `/ases-release $ARGUMENTS`
