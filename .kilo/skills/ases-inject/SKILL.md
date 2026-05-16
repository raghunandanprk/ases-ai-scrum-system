---
name: ases-inject
description: >
  ASES Manual Context Injection — PO injects specific global context entries by ID into
  the current session. Invoke with /ases-inject [ID...] e.g. /ases-inject DS-003 SP-001 TD-002.
  Reads those specific entries from .ases/global_context.json and injects them as an
  <ases-injected-context> block. Supports ID list or tag-based: /ases-inject tags:M-001,performance.
  PO-facing command — has access to global_context.json.
allowed-tools: Read, Write
argument-hint: "[ID...] e.g. DS-003 SP-001  OR  tags:module,keyword"
---

# ASES `/ases-inject [IDs or tags:...]`
**Agent:** PO (Human) · **Scope:** Session · **Access:** global_context.json

---

## Parse Arguments

Arguments can be:
- **ID list:** `DS-003 SP-001 TD-002` — inject those specific entries
- **Tag-based:** `tags:M-001,performance` — inject all entries matching ALL listed tags
- **Type-based:** `type:decision` — inject all entries of that type

---

## Step 1 — Read Global Context

Read `.ases/global_context.json`

**Valid ID prefixes:**
| Prefix | Type |
|---|---|
| `SP-NNN` | Sprint digest |
| `DS-NNN` | Architectural decision (ADR) |
| `TD-NNN` | Tech debt item |
| `FT-NNN` | Shipped feature |
| `RI-NNN` | Risk item |
| `CF-NNN` | Carry-forward item |

---

## Step 2 — Resolve Entries

For ID-based: find entries where `entry.id` matches each argument.
For tag-based: find entries where ALL requested tags appear in `entry.tags[]`.
For type-based: find entries where `entry.type` matches.

If an ID is not found → report which IDs were not found. Continue with found ones.

---

## Step 3 — Output Injection Block

Output to the session as:

```
<ases-injected-context>
[MANUAL INJECTION — PO requested: {arguments}]

{for each matched entry}
--- {entry.id} | {entry.type} | {entry.sprint} ---
{if decision}: Decision: {entry.decision}
              Rationale: {entry.rationale}
              Tradeoffs: {entry.tradeoffs}
{if sprint_digest}: Summary: {entry.summary}
                   Verdict: {entry.verdict}
                   Full ref: {entry.full_ref}
{if tech_debt}: {entry.description} | severity: {entry.severity} | status: {entry.status}
{if feature}: {entry.name} | AC: {entry.ac_passed}/{entry.ac_count} | sprint: {entry.sprint}
{if risk}: {entry.description} | severity: {entry.severity} | mitigation: {entry.mitigation_status}
{if carry_forward}: {entry.description} | from: {entry.from_sprint} → {entry.to_sprint}
{end}
</ases-injected-context>
```

---

## Step 4 — Write Injection Log

Append to `.ases/.audit.log`:
```
[INJECT] {timestamp} PO injected: {resolved IDs} into session
```

---

## Note on Tag-Based Injection

Tags are already defined in `global_context.json` entries.
Common tag patterns:
- Module tags: `M-001`, `M-002`
- Feature tags: `F-001`, `F-007`
- Sprint tags: `S1`, `S2`
- Topic tags: `performance`, `security`, `database`, `architecture`
