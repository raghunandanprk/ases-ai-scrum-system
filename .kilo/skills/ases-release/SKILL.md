---
name: ases-release
description: >
  ASES Sprint Ship — Stamp the sprint as shipped, write CHANGELOG entry, update roadmap,
  prepare next sprint. Invoke with /ases-release [sprint-id] after /ases-final-audit
  SHIP/CONDITIONAL_SHIP and PO approval. Official sprint close. Sets up next sprint inputs.
allowed-tools: Read, Write
argument-hint: "[sprint-id e.g. S1]"
---

# ASES `/ases-release [sprint-id]`
**Agent:** Planner (Opus) · **Scope:** Sprint · **Requires:** PO approval of final_audit.md

## Input
Read `sprints/$ARGUMENTS/ship/final_audit.json`,
`sprints/$ARGUMENTS/ship/uat_report.json`,
`sprints/$ARGUMENTS/ship/sprint_summary.json`,
`sprints/$ARGUMENTS/ship/devops_log.json`,
`contracts/roadmap.json`, `.ases/context.json`

## Process
1. Stamp `context.json sprint_history` — status, verdict, features, tech debt
2. Append entry to `CHANGELOG.md`
3. Update `roadmap.json` — mark sprint complete, adjust future scope if needed
4. Prepare next sprint inputs from `sprint_summary.next_sprint_inputs`
5. Set `context.json current_sprint` → next sprint ID
6. Set `context.json current_phase` → `SPRINT_DESIGN`

## CHANGELOG Entry Format
```markdown
## Sprint {id} — {date}
**Goal:** {sprint_goal}
**Verdict:** {final_audit.verdict}

### Shipped
{features_shipped with AC count}

### Tech Debt
{tech_debt items}

### Deferred
{deferred_tasks}

### Commit
{devops_log.commit_hash}
```

## Output
```
.ases/context.json    ← sprint_history stamped, next sprint ready
contracts/roadmap.json    ← updated
CHANGELOG.md         ← entry appended
sprints/$ARGUMENTS/ship/release.json
sprints/$ARGUMENTS/ship/release.md
```

## Sprint cycle complete.
Return to Phase 1 Sprint Design for next sprint:
`/ases-prd-update [next-sprint-id]` (optional) → `/ases-lld [next-sprint-id]`

---

## Write Global Context Entries

After stamping context.json, write new entries to `.ases/global_context.json`:

**Sprint Digest (SP-NNN):**
```json
{
  "id": "SP-00N",
  "type": "sprint_digest",
  "sprint": "$ARGUMENTS",
  "summary": "<one-sentence sprint outcome>",
  "verdict": "<final_audit.verdict>",
  "date": "<ISO-8601>",
  "tags": ["S1", "shipped"],
  "full_ref": "sprints/$ARGUMENTS/ship/sprint_summary.json"
}
```

**Feature entries (FT-NNN) for each shipped feature:**
```json
{
  "id": "FT-00N",
  "type": "feature",
  "feature_id": "F-001",
  "name": "<feature name>",
  "sprint": "$ARGUMENTS",
  "ac_count": N,
  "ac_passed": N,
  "date": "<ISO-8601>",
  "tags": ["F-001", "$ARGUMENTS"]
}
```

**Tech debt entries (TD-NNN) from final_audit:**
Each `final_audit.tech_debt[]` item that is `status: open` becomes a TD-NNN entry.

**Carry-forward entries (CF-NNN) from sprint_summary:**
Each `sprint_summary.deferred_tasks[]` item becomes a CF-NNN entry.

Assign IDs sequentially (read existing entries to find next N).
Write updated `.ases/global_context.json` and `.ases/global_context.md`.
