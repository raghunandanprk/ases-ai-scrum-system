/**
 * ASES Guard v3.2 — ases-guard.ts
 * Kilo Code Plugin Port of ases-hook.py
 *
 * Context Augmentation Layer for the AI Scrum Engineering System.
 * Runs as tool.execute.before on every ASES command.
 *
 * Five jobs:
 *   1. Context injection — levels 2+3 + sub-agent config into every session
 *   2. PO-only file access guard — blocks reads of protected files
 *   3. Commit guard — blocks git commit unless UAT approved
 *   4. UI scaffold guard — blocks writes to frontend/ outside integration_points
 *   5. Sub-agent config injection — reads system.yaml sub_agents section
 */

import type { Plugin } from "@kilocode/plugin";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { join, relative, resolve } from "path";

// ── CONFIG ──────────────────────────────────────────────────────────

const CONTEXT_BRACKETS: Record<string, number> = {
  FRESH: 0.7,     // >70% remaining — full injection
  MODERATE: 0.4,  // 40-70% remaining — abbreviated
  DEPLETED: 0.15, // 15-40% remaining — minimal
  // <15% — CRITICAL, suggest /compact
};

const PO_ONLY_FILES = [
  ".ases/decisions.json",
  ".ases/decisions.md",
  ".ases/global_context.json",
  ".ases/global_context.md",
  "docs/prd.md",
  "docs/roadmap.md",
  "docs/hld.md",
];

const PO_FACING_COMMANDS = [
  "ases-uat", "ases-roadmap", "ases-prd-update", "ases-release",
  "ases-inject", "ases-context", "ases-status", "ases-prd",
  "ases-hld", "ases-interview",
];

// ── HELPERS ──────────────────────────────────────────────────────────

function findProjectRoot(startDir: string): string {
  let dir = startDir;
  for (let i = 0; i < 10; i++) {
    if (existsSync(join(dir, ".ases"))) return dir;
    const parent = resolve(dir, "..");
    if (parent === dir) break;
    dir = parent;
  }
  return startDir;
}

function loadJson(path: string): Record<string, any> | null {
  try {
    if (!existsSync(path)) return null;
    return JSON.parse(readFileSync(path, "utf-8"));
  } catch {
    return null;
  }
}

function activeCommand(args: Record<string, any>): string {
  const cmd = String(args.command ?? args.file_path ?? args.path ?? "");
  const match = cmd.match(/ases-[\w-]+/);
  return match ? match[0] : "";
}

function isPOCommand(cmd: string): boolean {
  return PO_FACING_COMMANDS.some((poc) => cmd.includes(poc));
}

function loadSubAgentConfig(root: string): Record<string, any> {
  const yamlPaths = [
    join(root, ".kilo", "system.yaml"),
    join(root, ".claude", "system.yaml"),
  ];
  for (const yamlPath of yamlPaths) {
    if (!existsSync(yamlPath)) continue;
    try {
      const text = readFileSync(yamlPath, "utf-8");
      const config: Record<string, any> = {};
      let inSection = false;
      for (const line of text.split("\n")) {
        const stripped = line.trim();
        if (stripped.startsWith("sub_agents:")) {
          inSection = true;
          continue;
        }
        if (inSection) {
          if (stripped && !stripped.startsWith("#") && !line.startsWith(" ")) {
            break; // Left the sub_agents section
          }
          if (stripped.includes(":") && !stripped.startsWith("#")) {
            const [key, ...rest] = stripped.split(":");
            const val = rest.join(":").trim().split("#")[0].trim();
            if (val.toLowerCase() === "true") config[key.trim()] = true;
            else if (val.toLowerCase() === "false") config[key.trim()] = false;
            else {
              const num = parseInt(val, 10);
              config[key.trim()] = isNaN(num) ? val : num;
            }
          }
        }
      }
      return config;
    } catch {
      return {};
    }
  }
  return {};
}

// ── JOB 1: CONTEXT INJECTION ────────────────────────────────────────

function buildInjection(root: string, bracket: string): string {
  const lines: string[] = ["<ases-state>"];

  // Level 3 — always
  const ctx = loadJson(join(root, ".ases", "context.json"));
  if (ctx) {
    lines.push(
      `project=${ctx.project ?? ""} sprint=${ctx.sprint ?? ""} ` +
      `phase=${ctx.phase ?? ""} stage=${ctx.stage ?? ""}`
    );
    lines.push(`last=${ctx.last_completed ?? ""} next=${ctx.next ?? ""}`);
    const blockers: string[] = ctx.blockers ?? [];
    if (blockers.length > 0) {
      lines.push(`BLOCKERS: ${blockers.join(", ")}`);
    }
  }

  // Level 2 — sprint context
  const sprintCtx = loadJson(join(root, ".ases", "sprint_context.json"));
  if (sprintCtx && ctx && sprintCtx.sprint_id === ctx.sprint) {
    if (bracket === "FRESH" || bracket === "MODERATE") {
      lines.push(`sprint_goal=${sprintCtx.sprint_goal ?? ""}`);
      const ts = sprintCtx.tasks_status ?? {};
      lines.push(
        `tasks: ${ts.complete ?? 0}/${ts.total ?? 0} done | ` +
        `${ts.in_progress ?? 0} in-progress | ${ts.pending ?? 0} pending`
      );
      const issues: any[] = sprintCtx.open_issues ?? [];
      if (issues.length > 0) {
        lines.push(`open_issues: ${issues.length}`);
      }

      // Resolve relevant decisions from global context
      const decisionIds: string[] = sprintCtx.relevant_decisions ?? [];
      if (decisionIds.length > 0) {
        const gc = loadJson(join(root, ".ases", "global_context.json"));
        if (gc) {
          for (const entry of gc.entries ?? []) {
            if (decisionIds.includes(entry.id) && entry.type === "decision") {
              lines.push(`ADR ${entry.id}: ${String(entry.decision ?? "").slice(0, 80)}`);
            }
          }
        }
      }
    } else {
      // DEPLETED — minimal
      const ts = sprintCtx.tasks_status ?? {};
      lines.push(
        `sprint=${sprintCtx.sprint_id ?? ""} tasks=${ts.complete ?? 0}/${ts.total ?? 0}`
      );
    }
  }

  // CRITICAL warning
  if (bracket === "CRITICAL") {
    lines.push("⚠ CONTEXT CRITICAL — run /compact before continuing");
  }

  // Sub-agent config injection
  const saConfig = loadSubAgentConfig(root);
  if (saConfig.enabled) {
    const saParts = [`sub_agents=${saConfig.enabled ?? false}`];
    if (saConfig.context_window !== undefined) {
      saParts.push(`context_window=${saConfig.context_window}`);
    }
    if (saConfig.threshold !== undefined) {
      saParts.push(`threshold=${saConfig.threshold}`);
    }
    lines.push(saParts.join(" "));
  }

  lines.push("</ases-state>");
  return lines.join("\n");
}

// ── JOB 2: PO-ONLY FILE GUARD ──────────────────────────────────────

function checkPOGuard(
  tool: string,
  args: Record<string, any>,
  cmd: string,
  root: string
): string | null {
  if (tool !== "read_file" && tool !== "read") return null;

  const filePath = String(args.file_path ?? args.path ?? "");
  if (!filePath) return null;

  let rel: string;
  try {
    rel = relative(root, resolve(root, filePath));
  } catch {
    rel = filePath;
  }

  for (const protected_ of PO_ONLY_FILES) {
    if (rel.includes(protected_) || rel.endsWith(protected_.replace(/^\//, ""))) {
      if (!isPOCommand(cmd)) {
        return (
          `[ASES GUARD] '${rel}' is a PO-only file.\n` +
          `It may only be read by PO-facing commands: ${PO_FACING_COMMANDS.join(", ")}.\n` +
          `Current command '${cmd}' does not have access.\n` +
          `Use /ases-inject [ID] to selectively inject specific global context entries.`
        );
      }
    }
  }
  return null;
}

// ── JOB 3: COMMIT GUARD ─────────────────────────────────────────────

function checkCommitGuard(
  args: Record<string, any>,
  root: string
): string | null {
  const command = String(args.command ?? "");
  if (!command.includes("git commit")) return null;

  const ctx = loadJson(join(root, ".ases", "context.json"));
  if (!ctx) return "[ASES GUARD] context.json not found — commit blocked.";

  if (ctx.phase !== "SPRINT_SHIP") {
    return `[ASES GUARD] Phase is '${ctx.phase}', not SPRINT_SHIP — commit blocked.`;
  }

  const sprint = ctx.sprint ?? "S1";
  const uatPath = join(root, "sprints", sprint, "ship", "uat_report.json");
  const uat = loadJson(uatPath);
  if (!uat) {
    return `[ASES GUARD] uat_report.json not found for ${sprint} — run /ases-uat first.`;
  }

  const verdict = uat.verdict ?? "";
  if (verdict !== "APPROVED" && verdict !== "CONDITIONAL") {
    return `[ASES GUARD] UAT verdict is '${verdict}' — commit blocked. Must be APPROVED or CONDITIONAL.`;
  }

  return null;
}

// ── JOB 4: UI SCAFFOLD GUARD ────────────────────────────────────────

function checkUIGuard(
  tool: string,
  args: Record<string, any>,
  root: string
): string | null {
  if (tool !== "write_file" && tool !== "edit") return null;

  const filePath = String(args.file_path ?? args.path ?? "");
  if (!filePath.includes("/frontend/") && !filePath.startsWith("frontend/")) {
    return null;
  }

  const ctx = loadJson(join(root, ".ases", "context.json"));
  if (!ctx) return null;

  const sprint = ctx.sprint ?? "S1";
  const manifestPath = join(root, "sprints", sprint, "execution", "ui_scaffold_manifest.json");
  const manifest = loadJson(manifestPath);
  if (!manifest) return null; // Scaffold being built — allow

  const allowed = new Set<string>();
  for (const comp of manifest.components ?? []) {
    for (const ip of comp.integration_points ?? []) {
      const loc = ip.location ?? "";
      if (loc) allowed.add(loc);
    }
  }

  const rel = filePath.replace("./frontend/", "").replace("frontend/", "");
  const isAllowed = Array.from(allowed).some(
    (loc) => rel.includes(loc) || loc.includes(rel)
  );

  if (!isAllowed) {
    return (
      `[ASES GUARD] UI scaffold is locked. '${filePath}' is not a declared integration_point.\n` +
      `Allowed: ${JSON.stringify(Array.from(allowed).sort())}\n` +
      `Only Gemini may modify UI scaffold structure. Execution agent may only touch integration_points.`
    );
  }
  return null;
}

// ── PLUGIN EXPORT ───────────────────────────────────────────────────

const asesGuard: Plugin = async ({ directory }) => {
  const root = findProjectRoot(directory);

  return {
    "tool.execute.before": async (input, output) => {
      const { tool, args } = input;
      const cmd = activeCommand(args);

      // Job 2 — PO-only file guard
      const poBlock = checkPOGuard(tool, args, cmd, root);
      if (poBlock) throw new Error(poBlock);

      // Job 3 — Commit guard
      if (tool === "bash") {
        const commitBlock = checkCommitGuard(args, root);
        if (commitBlock) throw new Error(commitBlock);
      }

      // Job 4 — UI scaffold guard
      const uiBlock = checkUIGuard(tool, args, root);
      if (uiBlock) throw new Error(uiBlock);

      // Job 1 — Context injection (on ASES skill invocations)
      if (cmd.startsWith("ases-")) {
        const bracket = "FRESH"; // Kilo doesn't expose token counts the same way
        const injection = buildInjection(root, bracket);
        const injectPath = join(root, ".ases", ".current_injection.md");
        writeFileSync(injectPath, injection, "utf-8");
        console.log(`[ASES] Context injected (${bracket}) for ${cmd}`);
      }

      return output;
    },
  };
};

export default { id: "ases-guard", server: asesGuard };
