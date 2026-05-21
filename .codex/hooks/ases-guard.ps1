#Requires -Version 5.1
<#
.SYNOPSIS
    ASES Guard v3.2 — ases-guard.ps1
    Codex Platform Hook (PowerShell) for the AI Scrum Engineering System.

.DESCRIPTION
    PowerShell port of ases-hook.py (Claude) / ases-guard.ts (Kilo) / ases-guard.sh (Bash).
    Runs as PreToolUse hook on every ASES command in Codex on Windows.

    Five jobs:
      1. Context injection — levels 2+3 + sub-agent config into every session
      2. PO-only file access guard — blocks reads of protected files
      3. Commit guard — blocks git commit unless UAT approved
      4. UI scaffold guard — blocks writes to frontend/ outside integration_points
      5. Sub-agent config injection — reads system.yaml sub_agents section

    Protocol: JSON on stdin → exit 0 (allow) or exit 2 (block)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── CONFIG ───────────────────────────────────────────────────────────

$PO_ONLY_FILES = @(
    ".ases/decisions.json"
    ".ases/decisions.md"
    ".ases/global_context.json"
    ".ases/global_context.md"
    "docs/prd.md"
    "docs/roadmap.md"
    "docs/hld.md"
)

$PO_FACING_COMMANDS = @(
    "ases-uat", "ases-roadmap", "ases-prd-update", "ases-release",
    "ases-inject", "ases-context", "ases-status", "ases-prd",
    "ases-hld", "ases-interview"
)

# ── HELPERS ──────────────────────────────────────────────────────────

function Find-ProjectRoot {
    param([string]$StartDir = (Get-Location).Path)
    $dir = $StartDir
    for ($i = 0; $i -lt 10; $i++) {
        if (Test-Path (Join-Path $dir ".ases")) {
            return $dir
        }
        $parent = Split-Path $dir -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return (Get-Location).Path
}

function Read-JsonFile {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            return Get-Content $Path -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Get-ActiveCommand {
    param([string]$Input)
    if ($Input -match '(ases-[\w-]+)') {
        return $Matches[1]
    }
    return ""
}

function Test-POCommand {
    param([string]$Cmd)
    foreach ($poc in $PO_FACING_COMMANDS) {
        if ($Cmd -like "*$poc*") { return $true }
    }
    return $false
}

# ── JOB 1: CONTEXT INJECTION ────────────────────────────────────────

function Build-Injection {
    param([string]$Root)
    $lines = [System.Collections.ArrayList]@()
    [void]$lines.Add("<ases-state>")

    # Level 3 — always
    $ctxPath = Join-Path $Root ".ases" "context.json"
    $ctx = Read-JsonFile $ctxPath
    if ($ctx) {
        $project = if ($ctx.project) { $ctx.project } else { "" }
        $sprint  = if ($ctx.sprint)  { $ctx.sprint }  else { "" }
        $phase   = if ($ctx.phase)   { $ctx.phase }   else { "" }
        $stage   = if ($ctx.stage)   { $ctx.stage }   else { "" }
        [void]$lines.Add("project=$project sprint=$sprint phase=$phase stage=$stage")

        $last = if ($ctx.last_completed) { $ctx.last_completed } else { "" }
        $next = if ($ctx.next) { $ctx.next } else { "" }
        [void]$lines.Add("last=$last next=$next")

        if ($ctx.blockers -and $ctx.blockers.Count -gt 0) {
            [void]$lines.Add("BLOCKERS: $($ctx.blockers -join ', ')")
        }
    }

    # Level 2 — sprint context
    $sprintPath = Join-Path $Root ".ases" "sprint_context.json"
    $sprintCtx = Read-JsonFile $sprintPath
    if ($sprintCtx -and $ctx -and $sprintCtx.sprint_id -eq $ctx.sprint) {
        $goal = if ($sprintCtx.sprint_goal) { $sprintCtx.sprint_goal } else { "" }
        [void]$lines.Add("sprint_goal=$goal")

        $ts = $sprintCtx.tasks_status
        if ($ts) {
            $complete    = if ($ts.complete)    { $ts.complete }    else { 0 }
            $total       = if ($ts.total)       { $ts.total }       else { 0 }
            $inProgress  = if ($ts.in_progress) { $ts.in_progress } else { 0 }
            $pending     = if ($ts.pending)     { $ts.pending }     else { 0 }
            [void]$lines.Add("tasks: $complete/$total done | $inProgress in-progress | $pending pending")
        }

        if ($sprintCtx.open_issues -and $sprintCtx.open_issues.Count -gt 0) {
            [void]$lines.Add("open_issues: $($sprintCtx.open_issues.Count)")
        }
    }

    # Sub-agent config injection
    $yamlPaths = @(
        (Join-Path $Root ".codex" "system.yaml"),
        (Join-Path $Root ".claude" "system.yaml"),
        (Join-Path $Root ".kilo" "system.yaml")
    )
    foreach ($yamlPath in $yamlPaths) {
        if (Test-Path $yamlPath) {
            $yamlText = Get-Content $yamlPath -Raw
            if ($yamlText -match 'sub_agents:') {
                $inSection = $false
                $saConfig = @{}
                foreach ($line in ($yamlText -split "`n")) {
                    $stripped = $line.Trim()
                    if ($stripped -match '^sub_agents:') {
                        $inSection = $true
                        continue
                    }
                    if ($inSection) {
                        if ($stripped -and -not $stripped.StartsWith('#') -and -not $line.StartsWith(' ')) {
                            break
                        }
                        if ($stripped -match '^(\w+):\s*(.+)$' -and -not $stripped.StartsWith('#')) {
                            $key = $Matches[1].Trim()
                            $val = ($Matches[2] -split '#')[0].Trim()
                            if ($val -eq 'true') { $saConfig[$key] = $true }
                            elseif ($val -eq 'false') { $saConfig[$key] = $false }
                            else {
                                $num = 0
                                if ([int]::TryParse($val, [ref]$num)) { $saConfig[$key] = $num }
                                else { $saConfig[$key] = $val }
                            }
                        }
                    }
                }
                if ($saConfig['enabled'] -eq $true) {
                    $saParts = @("sub_agents=true")
                    if ($saConfig.ContainsKey('context_window')) { $saParts += "context_window=$($saConfig['context_window'])" }
                    if ($saConfig.ContainsKey('threshold')) { $saParts += "threshold=$($saConfig['threshold'])" }
                    [void]$lines.Add($saParts -join ' ')
                }
            }
            break
        }
    }

    [void]$lines.Add("</ases-state>")
    return $lines -join "`n"
}

# ── JOB 2: PO-ONLY FILE GUARD ───────────────────────────────────────

function Test-POGuard {
    param(
        [string]$ToolName,
        [string]$FilePath,
        [string]$Cmd
    )

    if ($ToolName -notin @("Read", "View")) { return $null }
    if ([string]::IsNullOrEmpty($FilePath)) { return $null }

    foreach ($protected in $PO_ONLY_FILES) {
        if ($FilePath -like "*$protected*") {
            if (-not (Test-POCommand $Cmd)) {
                return @(
                    "[ASES GUARD] '$FilePath' is a PO-only file.",
                    "It may only be read by PO-facing commands: $($PO_FACING_COMMANDS -join ', ').",
                    "Current command '$Cmd' does not have access.",
                    "Use /ases-inject [ID] to selectively inject specific global context entries."
                ) -join "`n"
            }
        }
    }
    return $null
}

# ── JOB 3: COMMIT GUARD ─────────────────────────────────────────────

function Test-CommitGuard {
    param(
        [string]$CommandStr,
        [string]$Root
    )

    if ($CommandStr -notlike "*git commit*") { return $null }

    $ctxPath = Join-Path $Root ".ases" "context.json"
    $ctx = Read-JsonFile $ctxPath
    if (-not $ctx) {
        return "[ASES GUARD] context.json not found — commit blocked."
    }

    if ($ctx.phase -ne "SPRINT_SHIP") {
        return "[ASES GUARD] Phase is '$($ctx.phase)', not SPRINT_SHIP — commit blocked."
    }

    $sprint = if ($ctx.sprint) { $ctx.sprint } else { "S1" }
    $uatPath = Join-Path $Root "sprints" $sprint "ship" "uat_report.json"
    $uat = Read-JsonFile $uatPath
    if (-not $uat) {
        return "[ASES GUARD] uat_report.json not found for $sprint — run /ases-uat first."
    }

    $verdict = if ($uat.verdict) { $uat.verdict } else { "" }
    if ($verdict -notin @("APPROVED", "CONDITIONAL")) {
        return "[ASES GUARD] UAT verdict is '$verdict' — commit blocked. Must be APPROVED or CONDITIONAL."
    }

    return $null
}

# ── JOB 4: UI SCAFFOLD GUARD ────────────────────────────────────────

function Test-UIGuard {
    param(
        [string]$ToolName,
        [string]$FilePath,
        [string]$Root
    )

    if ($ToolName -notin @("apply_patch", "Write", "edit")) { return $null }
    if ($FilePath -notlike "*frontend/*" -and $FilePath -notlike "frontend/*") { return $null }

    $ctxPath = Join-Path $Root ".ases" "context.json"
    $ctx = Read-JsonFile $ctxPath
    if (-not $ctx) { return $null }

    $sprint = if ($ctx.sprint) { $ctx.sprint } else { "S1" }
    $manifestPath = Join-Path $Root "sprints" $sprint "execution" "ui_scaffold_manifest.json"
    $manifest = Read-JsonFile $manifestPath
    if (-not $manifest) { return $null }  # Scaffold being built — allow

    $allowed = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($comp in $manifest.components) {
        foreach ($ip in $comp.integration_points) {
            $loc = $ip.location
            if ($loc) { [void]$allowed.Add($loc) }
        }
    }

    $rel = $FilePath -replace '\.?/?frontend/', ''
    $isAllowed = $false
    foreach ($loc in $allowed) {
        if ($rel -like "*$loc*" -or $loc -like "*$rel*") {
            $isAllowed = $true
            break
        }
    }

    if (-not $isAllowed) {
        return @(
            "[ASES GUARD] UI scaffold is locked. '$FilePath' is not a declared integration_point.",
            "Allowed: $($allowed | Sort-Object | ConvertTo-Json -Compress)",
            "Only Gemini may modify UI scaffold structure. Execution agent may only touch integration_points."
        ) -join "`n"
    }
    return $null
}

# ── MAIN ─────────────────────────────────────────────────────────────

function Main {
    # Read JSON input from stdin
    $inputText = [Console]::In.ReadToEnd()
    try {
        $hookInput = $inputText | ConvertFrom-Json
    } catch {
        exit 0
    }

    $toolName   = if ($hookInput.tool_name)            { $hookInput.tool_name }            else { "" }
    $filePath   = if ($hookInput.tool_input.file_path)  { $hookInput.tool_input.file_path }  elseif ($hookInput.tool_input.path) { $hookInput.tool_input.path } else { "" }
    $commandStr = if ($hookInput.tool_input.command)    { $hookInput.tool_input.command }    else { "" }

    $root = Find-ProjectRoot
    $cmd  = Get-ActiveCommand "$commandStr$filePath"

    # Job 2 — PO-only guard
    $poBlock = Test-POGuard -ToolName $toolName -FilePath $filePath -Cmd $cmd
    if ($poBlock) {
        Write-Error $poBlock
        exit 2
    }

    # Job 3 — Commit guard
    if ($toolName -eq "Bash") {
        $commitBlock = Test-CommitGuard -CommandStr $commandStr -Root $root
        if ($commitBlock) {
            Write-Error $commitBlock
            exit 2
        }
    }

    # Job 4 — UI scaffold guard
    $uiBlock = Test-UIGuard -ToolName $toolName -FilePath $filePath -Root $root
    if ($uiBlock) {
        Write-Error $uiBlock
        exit 2
    }

    # Job 1 — Context injection (on ASES skill invocations)
    if ($cmd -like "ases-*") {
        $injection = Build-Injection -Root $root
        $injectPath = Join-Path $root ".ases" ".current_injection.md"
        Set-Content -Path $injectPath -Value $injection -Encoding UTF8
        Write-Host "[ASES] Context injected for $cmd" -ForegroundColor DarkGray
    }

    exit 0
}

Main
