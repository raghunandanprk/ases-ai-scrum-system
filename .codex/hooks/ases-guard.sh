#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# ASES Guard v3.2 — ases-guard.sh
# Codex Platform Port of ases-hook.py (Claude) / ases-guard.ts (Kilo)
#
# Context Augmentation Layer for the AI Scrum Engineering System.
# Runs as PreToolUse hook on every ASES command in Codex.
#
# Five jobs:
#   1. Context injection — levels 2+3 + sub-agent config into every session
#   2. PO-only file access guard — blocks reads of protected files
#   3. Commit guard — blocks git commit unless UAT approved
#   4. UI scaffold guard — blocks writes to frontend/ outside integration_points
#   5. Sub-agent config injection — reads system.yaml sub_agents section
#
# Protocol: JSON on stdin → exit 0 (allow) or exit 2 (block)
# Requires: jq (JSON processor)
# ──────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── CONFIG ───────────────────────────────────────────────────────────

PO_ONLY_FILES=(
  ".ases/decisions.json"
  ".ases/decisions.md"
  ".ases/global_context.json"
  ".ases/global_context.md"
  "docs/prd.md"
  "docs/roadmap.md"
  "docs/hld.md"
)

PO_FACING_COMMANDS=(
  "ases-uat" "ases-roadmap" "ases-prd-update" "ases-release"
  "ases-inject" "ases-context" "ases-status" "ases-prd"
  "ases-hld" "ases-interview"
)

# ── HELPERS ──────────────────────────────────────────────────────────

find_project_root() {
  local dir="${1:-$(pwd)}"
  local i=0
  while [ $i -lt 10 ]; do
    if [ -d "$dir/.ases" ]; then
      echo "$dir"
      return 0
    fi
    local parent
    parent="$(cd "$dir/.." 2>/dev/null && pwd)"
    [ "$parent" = "$dir" ] && break
    dir="$parent"
    i=$((i + 1))
  done
  pwd
}

load_json_field() {
  local file="$1"
  local field="$2"
  local default="${3:-}"
  if [ -f "$file" ]; then
    local val
    val=$(jq -r ".$field // \"$default\"" "$file" 2>/dev/null)
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

active_command() {
  local input="$1"
  echo "$input" | grep -oP 'ases-[\w-]+' | head -1 || echo ""
}

is_po_command() {
  local cmd="$1"
  for poc in "${PO_FACING_COMMANDS[@]}"; do
    if [[ "$cmd" == *"$poc"* ]]; then
      return 0
    fi
  done
  return 1
}

# ── JOB 1: CONTEXT INJECTION ────────────────────────────────────────

build_injection() {
  local root="$1"
  local lines=("<ases-state>")

  # Level 3 — always
  local ctx_file="$root/.ases/context.json"
  if [ -f "$ctx_file" ]; then
    local project sprint phase stage last_completed next
    project=$(jq -r '.project // ""' "$ctx_file" 2>/dev/null)
    sprint=$(jq -r '.sprint // ""' "$ctx_file" 2>/dev/null)
    phase=$(jq -r '.phase // ""' "$ctx_file" 2>/dev/null)
    stage=$(jq -r '.stage // ""' "$ctx_file" 2>/dev/null)
    last_completed=$(jq -r '.last_completed // ""' "$ctx_file" 2>/dev/null)
    next=$(jq -r '.next // ""' "$ctx_file" 2>/dev/null)

    lines+=("project=$project sprint=$sprint phase=$phase stage=$stage")
    lines+=("last=$last_completed next=$next")

    local blockers
    blockers=$(jq -r '.blockers // [] | join(", ")' "$ctx_file" 2>/dev/null)
    if [ -n "$blockers" ]; then
      lines+=("BLOCKERS: $blockers")
    fi
  fi

  # Level 2 — sprint context
  local sprint_file="$root/.ases/sprint_context.json"
  if [ -f "$sprint_file" ] && [ -f "$ctx_file" ]; then
    local sprint_id ctx_sprint
    sprint_id=$(jq -r '.sprint_id // ""' "$sprint_file" 2>/dev/null)
    ctx_sprint=$(jq -r '.sprint // ""' "$ctx_file" 2>/dev/null)

    if [ "$sprint_id" = "$ctx_sprint" ]; then
      local sprint_goal
      sprint_goal=$(jq -r '.sprint_goal // ""' "$sprint_file" 2>/dev/null)
      lines+=("sprint_goal=$sprint_goal")

      local complete total in_progress pending
      complete=$(jq -r '.tasks_status.complete // 0' "$sprint_file" 2>/dev/null)
      total=$(jq -r '.tasks_status.total // 0' "$sprint_file" 2>/dev/null)
      in_progress=$(jq -r '.tasks_status.in_progress // 0' "$sprint_file" 2>/dev/null)
      pending=$(jq -r '.tasks_status.pending // 0' "$sprint_file" 2>/dev/null)
      lines+=("tasks: ${complete}/${total} done | ${in_progress} in-progress | ${pending} pending")

      local issues_count
      issues_count=$(jq -r '.open_issues // [] | length' "$sprint_file" 2>/dev/null)
      if [ "$issues_count" -gt 0 ] 2>/dev/null; then
        lines+=("open_issues: $issues_count")
      fi
    fi
  fi

  # Sub-agent config injection
  local sa_enabled=""
  for yaml_path in "$root/.codex/system.yaml" "$root/.claude/system.yaml" "$root/.kilo/system.yaml"; do
    if [ -f "$yaml_path" ]; then
      sa_enabled=$(grep -A5 'sub_agents:' "$yaml_path" 2>/dev/null | grep 'enabled:' | head -1 | sed 's/.*enabled:\s*//' | sed 's/\s*#.*//' | tr -d '[:space:]')
      if [ "$sa_enabled" = "true" ]; then
        local context_window threshold
        context_window=$(grep -A5 'sub_agents:' "$yaml_path" 2>/dev/null | grep 'context_window:' | head -1 | sed 's/.*context_window:\s*//' | sed 's/\s*#.*//' | tr -d '[:space:]')
        threshold=$(grep -A5 'sub_agents:' "$yaml_path" 2>/dev/null | grep 'threshold:' | head -1 | sed 's/.*threshold:\s*//' | sed 's/\s*#.*//' | tr -d '[:space:]')
        local sa_line="sub_agents=true"
        [ -n "$context_window" ] && sa_line="$sa_line context_window=$context_window"
        [ -n "$threshold" ] && sa_line="$sa_line threshold=$threshold"
        lines+=("$sa_line")
      fi
      break
    fi
  done

  lines+=("</ases-state>")

  printf '%s\n' "${lines[@]}"
}

# ── JOB 2: PO-ONLY FILE GUARD ───────────────────────────────────────

check_po_guard() {
  local tool_name="$1"
  local file_path="$2"
  local cmd="$3"

  if [[ "$tool_name" != "Read" && "$tool_name" != "View" ]]; then
    return 0
  fi

  [ -z "$file_path" ] && return 0

  for protected in "${PO_ONLY_FILES[@]}"; do
    if [[ "$file_path" == *"$protected"* ]]; then
      if ! is_po_command "$cmd"; then
        echo "[ASES GUARD] '$file_path' is a PO-only file." >&2
        echo "It may only be read by PO-facing commands: ${PO_FACING_COMMANDS[*]}." >&2
        echo "Current command '$cmd' does not have access." >&2
        echo "Use /ases-inject [ID] to selectively inject specific global context entries." >&2
        return 1
      fi
    fi
  done
  return 0
}

# ── JOB 3: COMMIT GUARD ─────────────────────────────────────────────

check_commit_guard() {
  local command_str="$1"
  local root="$2"

  if [[ "$command_str" != *"git commit"* ]]; then
    return 0
  fi

  local ctx_file="$root/.ases/context.json"
  if [ ! -f "$ctx_file" ]; then
    echo "[ASES GUARD] context.json not found — commit blocked." >&2
    return 1
  fi

  local phase
  phase=$(jq -r '.phase // ""' "$ctx_file" 2>/dev/null)
  if [ "$phase" != "SPRINT_SHIP" ]; then
    echo "[ASES GUARD] Phase is '$phase', not SPRINT_SHIP — commit blocked." >&2
    return 1
  fi

  local sprint
  sprint=$(jq -r '.sprint // "S1"' "$ctx_file" 2>/dev/null)
  local uat_file="$root/sprints/$sprint/ship/uat_report.json"
  if [ ! -f "$uat_file" ]; then
    echo "[ASES GUARD] uat_report.json not found for $sprint — run /ases-uat first." >&2
    return 1
  fi

  local verdict
  verdict=$(jq -r '.verdict // ""' "$uat_file" 2>/dev/null)
  if [[ "$verdict" != "APPROVED" && "$verdict" != "CONDITIONAL" ]]; then
    echo "[ASES GUARD] UAT verdict is '$verdict' — commit blocked. Must be APPROVED or CONDITIONAL." >&2
    return 1
  fi

  return 0
}

# ── JOB 4: UI SCAFFOLD GUARD ────────────────────────────────────────

check_ui_guard() {
  local tool_name="$1"
  local file_path="$2"
  local root="$3"

  if [[ "$tool_name" != "apply_patch" && "$tool_name" != "Write" && "$tool_name" != "edit" ]]; then
    return 0
  fi

  if [[ "$file_path" != *"/frontend/"* && "$file_path" != "frontend/"* ]]; then
    return 0
  fi

  local ctx_file="$root/.ases/context.json"
  [ ! -f "$ctx_file" ] && return 0

  local sprint
  sprint=$(jq -r '.sprint // "S1"' "$ctx_file" 2>/dev/null)
  local manifest="$root/sprints/$sprint/execution/ui_scaffold_manifest.json"
  [ ! -f "$manifest" ] && return 0  # Scaffold being built — allow

  # Check if file is in allowed integration_points
  local rel_path="${file_path#*frontend/}"
  local is_allowed
  is_allowed=$(jq -r --arg rel "$rel_path" \
    '[.components[]?.integration_points[]?.location // empty] | map(select(. != "")) | map(select(test($rel) or ($rel | test(.)))) | length' \
    "$manifest" 2>/dev/null)

  if [ "${is_allowed:-0}" -eq 0 ]; then
    echo "[ASES GUARD] UI scaffold is locked. '$file_path' is not a declared integration_point." >&2
    echo "Only Gemini may modify UI scaffold structure. Execution agent may only touch integration_points." >&2
    return 1
  fi

  return 0
}

# ── MAIN ─────────────────────────────────────────────────────────────

main() {
  # Read JSON input from stdin
  local input
  input=$(cat)

  # Check if jq is available
  if ! command -v jq &>/dev/null; then
    echo "[ASES GUARD] Warning: jq not found. Guard checks skipped." >&2
    exit 0
  fi

  local tool_name file_path command_str
  tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)
  command_str=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)

  local root
  root=$(find_project_root)

  local cmd
  cmd=$(active_command "$command_str$file_path")

  # Job 2 — PO-only guard
  if ! check_po_guard "$tool_name" "$file_path" "$cmd"; then
    exit 2
  fi

  # Job 3 — Commit guard
  if [[ "$tool_name" == "Bash" ]]; then
    if ! check_commit_guard "$command_str" "$root"; then
      exit 2
    fi
  fi

  # Job 4 — UI scaffold guard
  if ! check_ui_guard "$tool_name" "$file_path" "$root"; then
    exit 2
  fi

  # Job 1 — Context injection (on ASES skill invocations)
  if [[ "$cmd" == ases-* ]]; then
    local injection
    injection=$(build_injection "$root")
    local inject_path="$root/.ases/.current_injection.md"
    echo "$injection" > "$inject_path"
    echo "[ASES] Context injected for $cmd" >&2
  fi

  exit 0
}

main
