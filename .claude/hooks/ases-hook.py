#!/usr/bin/env python3
"""
ASES Hook v3.2 — ases-hook.py
Context Augmentation Layer for the AI Scrum Engineering System.

Inspired by CARL's just-in-time rule injection pattern.
Runs as PreToolUse on every ASES command.

Four jobs:
  1. Context injection — levels 2+3 + sub-agent config into every session
  2. PO-only file access guard — blocks skill reads of protected files
  3. Context bracket logic — adjusts injection verbosity by window remaining
  4. Sub-agent config injection — reads system.yaml sub_agents section

Entry points registered in settings.json:
  PreToolUse: matcher "Bash(*ases*)" and "Read(*)"
"""

import json
import os
import sys
import re
from pathlib import Path
from datetime import datetime

# ── CONFIG ────────────────────────────────────────────────────────────

CONTEXT_BRACKETS = {
    "FRESH":    0.70,   # >70% remaining — full injection
    "MODERATE": 0.40,   # 40-70% remaining — abbreviated
    "DEPLETED": 0.15,   # 15-40% remaining — minimal
    # <15% — suggest /compact, inject nothing but warning
}

PO_ONLY_FILES = [
    ".ases/decisions.json",
    ".ases/decisions.md",
    ".ases/global_context.json",
    ".ases/global_context.md",
    "docs/prd.md",
    "docs/roadmap.md",
    "docs/hld.md",
]

PO_FACING_COMMANDS = [
    "ases-uat", "ases-roadmap", "ases-prd-update", "ases-release",
    "ases-inject", "ases-context", "ases-status", "ases-prd",
    "ases-hld", "ases-interview",
]

ID_PREFIXES = {
    "SP": "sprint_digest",
    "DS": "decision",
    "TD": "tech_debt",
    "FT": "feature",
    "RI": "risk",
    "CF": "carry_forward",
}

# ── HELPERS ───────────────────────────────────────────────────────────

def find_project_root():
    """Walk up from cwd to find ASES project root (.ases dir present)."""
    p = Path.cwd()
    for _ in range(10):
        if (p / ".ases").exists():
            return p
        p = p.parent
    return Path.cwd()

def load_json(path: Path):
    if path.exists():
        try:
            return json.loads(path.read_text())
        except json.JSONDecodeError:
            return None
    return None

def load_sub_agent_config(root: Path) -> dict:
    """Read sub_agents section from system.yaml. Returns empty dict if missing."""
    for yaml_path in [
        root / ".claude" / "system.yaml",
        root / ".kilo" / "system.yaml",
    ]:
        if yaml_path.exists():
            try:
                text = yaml_path.read_text()
                # Minimal YAML parse for sub_agents section (no PyYAML dependency)
                in_section = False
                config = {}
                for line in text.splitlines():
                    stripped = line.strip()
                    if stripped.startswith("sub_agents:"):
                        in_section = True
                        continue
                    if in_section:
                        if stripped and not stripped.startswith("#") and not line.startswith(" "):
                            break  # Left the sub_agents section
                        if ":" in stripped and not stripped.startswith("#"):
                            key, _, val = stripped.partition(":")
                            val = val.strip().split("#")[0].strip()  # Remove inline comments
                            if val.lower() == "true":
                                config[key.strip()] = True
                            elif val.lower() == "false":
                                config[key.strip()] = False
                            else:
                                try:
                                    config[key.strip()] = int(val)
                                except ValueError:
                                    config[key.strip()] = val
                return config
            except Exception:
                return {}
    return {}

def get_context_bracket(env: dict) -> str:
    """Determine context window state from Claude Code env vars."""
    try:
        used = int(env.get("CLAUDE_TOKENS_USED", 0))
        limit = int(env.get("CLAUDE_TOKEN_LIMIT", 200000))
        if limit == 0:
            return "FRESH"
        remaining_pct = 1.0 - (used / limit)
        if remaining_pct >= CONTEXT_BRACKETS["FRESH"]:
            return "FRESH"
        elif remaining_pct >= CONTEXT_BRACKETS["MODERATE"]:
            return "MODERATE"
        elif remaining_pct >= CONTEXT_BRACKETS["DEPLETED"]:
            return "DEPLETED"
        else:
            return "CRITICAL"
    except (ValueError, TypeError):
        return "FRESH"

def active_command(tool_input: dict) -> str:
    """Extract the ASES command name from tool input."""
    cmd = tool_input.get("command", "") or tool_input.get("file_path", "")
    match = re.search(r"ases-[\w-]+", str(cmd))
    return match.group(0) if match else ""

def is_po_command(cmd: str) -> bool:
    return any(poc in cmd for poc in PO_FACING_COMMANDS)

# ── JOB 1: CONTEXT INJECTION ─────────────────────────────────────────

def build_injection(root: Path, bracket: str) -> str:
    """Build the <ases-state> injection block."""
    lines = ["<ases-state>"]

    # Level 3 — always
    ctx = load_json(root / ".ases" / "context.json")
    if ctx:
        lines.append(f"project={ctx.get('project','')} sprint={ctx.get('sprint','')} "
                     f"phase={ctx.get('phase','')} stage={ctx.get('stage','')}")
        lines.append(f"last={ctx.get('last_completed','')} next={ctx.get('next','')}")
        blockers = ctx.get("blockers", [])
        if blockers:
            lines.append(f"BLOCKERS: {', '.join(str(b) for b in blockers)}")

    # Level 2 — sprint context (only if sprint is active)
    sprint_ctx = load_json(root / ".ases" / "sprint_context.json")
    if sprint_ctx and ctx and sprint_ctx.get("sprint_id") == ctx.get("sprint"):
        if bracket in ("FRESH", "MODERATE"):
            lines.append(f"sprint_goal={sprint_ctx.get('sprint_goal','')}")
            ts = sprint_ctx.get("tasks_status", {})
            lines.append(f"tasks: {ts.get('complete',0)}/{ts.get('total',0)} done "
                         f"| {ts.get('in_progress',0)} in-progress "
                         f"| {ts.get('pending',0)} pending")
            issues = sprint_ctx.get("open_issues", [])
            if issues:
                lines.append(f"open_issues: {len(issues)}")

            # Resolve relevant_decisions from global_context
            decision_ids = sprint_ctx.get("relevant_decisions", [])
            if decision_ids:
                gc = load_json(root / ".ases" / "global_context.json")
                if gc:
                    for entry in gc.get("entries", []):
                        if entry.get("id") in decision_ids and entry.get("type") == "decision":
                            lines.append(f"ADR {entry['id']}: {entry.get('decision','')[:80]}")
        else:
            # DEPLETED — just sprint ID and task count
            ts = sprint_ctx.get("tasks_status", {})
            lines.append(f"sprint={sprint_ctx.get('sprint_id','')} "
                         f"tasks={ts.get('complete',0)}/{ts.get('total',0)}")

    # CRITICAL — warn only
    if bracket == "CRITICAL":
        lines.append("⚠ CONTEXT CRITICAL — run /compact before continuing")

    # Sub-agent config injection
    sa_config = load_sub_agent_config(root)
    if sa_config.get("enabled"):
        sa_parts = [f"sub_agents={sa_config.get('enabled', False)}"]
        if "context_window" in sa_config:
            sa_parts.append(f"context_window={sa_config['context_window']}")
        if "threshold" in sa_config:
            sa_parts.append(f"threshold={sa_config['threshold']}")
        lines.append(" ".join(sa_parts))

    lines.append("</ases-state>")
    return "\n".join(lines)

# ── JOB 2: PO-ONLY FILE GUARD ─────────────────────────────────────────

def check_po_guard(tool_name: str, tool_input: dict, cmd: str, root: Path) -> tuple[bool, str]:
    """
    Returns (blocked: bool, reason: str).
    Blocks reads of PO-only files unless the active command is PO-facing.
    """
    if tool_name not in ("Read", "View"):
        return False, ""

    file_path = str(tool_input.get("file_path", "") or tool_input.get("path", ""))
    if not file_path:
        return False, ""

    # Normalise to relative path
    try:
        rel = str(Path(file_path).relative_to(root))
    except ValueError:
        rel = file_path

    for protected in PO_ONLY_FILES:
        if protected in rel or rel.endswith(protected.lstrip("/")):
            if not is_po_command(cmd):
                return True, (
                    f"[ASES GUARD] '{rel}' is a PO-only file.\n"
                    f"It may only be read by PO-facing commands: {', '.join(PO_FACING_COMMANDS)}.\n"
                    f"Current command '{cmd}' does not have access.\n"
                    f"Use /ases-inject [ID] to selectively inject specific global context entries."
                )
    return False, ""

# ── JOB 3: COMMIT GUARD (replaces guard_commit.py) ───────────────────

def check_commit_guard(tool_input: dict, root: Path) -> tuple[bool, str]:
    """Block git commit unless UAT is approved."""
    cmd = str(tool_input.get("command", ""))
    if "git commit" not in cmd:
        return False, ""

    ctx = load_json(root / ".ases" / "context.json")
    if not ctx:
        return True, "[ASES GUARD] context.json not found — commit blocked."

    if ctx.get("phase") != "SPRINT_SHIP":
        return True, f"[ASES GUARD] Phase is '{ctx.get('phase')}', not SPRINT_SHIP — commit blocked."

    sprint = ctx.get("sprint", "S1")
    uat_path = root / "sprints" / sprint / "ship" / "uat_report.json"
    uat = load_json(uat_path)
    if not uat:
        return True, f"[ASES GUARD] uat_report.json not found for {sprint} — run /ases-uat first."

    verdict = uat.get("verdict", "")
    if verdict not in ("APPROVED", "CONDITIONAL"):
        return True, f"[ASES GUARD] UAT verdict is '{verdict}' — commit blocked. Must be APPROVED or CONDITIONAL."

    return False, ""

# ── JOB 4: UI SCAFFOLD GUARD (replaces guard_ui_scaffold.py) ──────────

def check_ui_guard(tool_name: str, tool_input: dict, root: Path) -> tuple[bool, str]:
    """Block writes to frontend/ outside declared integration_points."""
    if tool_name != "Write":
        return False, ""

    file_path = str(tool_input.get("file_path", "") or tool_input.get("path", ""))
    if "/frontend/" not in file_path and not file_path.startswith("frontend/"):
        return False, ""

    ctx = load_json(root / ".ases" / "context.json")
    if not ctx:
        return False, ""

    sprint = ctx.get("sprint", "S1")
    manifest_path = root / "sprints" / sprint / "execution" / "ui_scaffold_manifest.json"
    manifest = load_json(manifest_path)
    if not manifest:
        return False, ""  # Scaffold being built — allow

    allowed = set()
    for comp in manifest.get("components", []):
        for ip in comp.get("integration_points", []):
            loc = ip.get("location", "")
            if loc:
                allowed.add(loc)

    rel = file_path.replace("./frontend/", "").replace("frontend/", "")
    is_allowed = any(rel in loc or loc in rel for loc in allowed)

    if not is_allowed:
        return True, (
            f"[ASES GUARD] UI scaffold is locked. '{file_path}' is not a declared integration_point.\n"
            f"Allowed: {sorted(allowed)}\n"
            "Only Gemini may modify UI scaffold structure. Execution agent may only touch integration_points."
        )
    return False, ""

# ── MAIN ──────────────────────────────────────────────────────────────

def main():
    """
    Claude Code calls hooks by passing tool info via stdin as JSON.
    Hook outputs are written to stdout and interpreted by Claude Code.
    Exit 0 = allow. Exit 2 = block with message.
    """
    try:
        hook_input = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})
    env = os.environ.copy()
    root = find_project_root()
    bracket = get_context_bracket(env)
    cmd = active_command(tool_input)

    # Job 2 — PO-only guard
    blocked, reason = check_po_guard(tool_name, tool_input, cmd, root)
    if blocked:
        print(reason, file=sys.stderr)
        sys.exit(2)

    # Job 3 — Commit guard
    if tool_name == "Bash":
        blocked, reason = check_commit_guard(tool_input, root)
        if blocked:
            print(reason, file=sys.stderr)
            sys.exit(2)

    # Job 4 — UI scaffold guard
    blocked, reason = check_ui_guard(tool_name, tool_input, root)
    if blocked:
        print(reason, file=sys.stderr)
        sys.exit(2)

    # Job 1 — Context injection (on ASES skill invocations)
    if cmd.startswith("ases-"):
        injection = build_injection(root, bracket)
        # Write injection to a temp file Claude Code reads as system context
        inject_path = root / ".ases" / ".current_injection.md"
        inject_path.write_text(injection)
        print(f"[ASES] Context injected ({bracket}) for {cmd}", file=sys.stderr)

    sys.exit(0)

if __name__ == "__main__":
    main()
