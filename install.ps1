#
# Pyth Entropy Skill — One-Command Installer (Windows PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/MJD2003/pyth-entropy-skill/main/install.ps1 | iex
#
# Or locally:
#   .\install.ps1 [-Windsurf] [-Cursor] [-Claude] [-Project "C:\path\to\project"]
#

param(
    [switch]$Windsurf,
    [switch]$Cursor,
    [switch]$Claude,
    [switch]$All,
    [string]$Project = ""
)

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/MJD2003/pyth-entropy-skill.git"
$SkillName = "pyth-entropy"

Write-Host ""
Write-Host "  Pyth Entropy Skill Installer" -ForegroundColor Cyan
Write-Host ""

# ─── Auto-detect if no flags ────────────────────────────

if (-not $Windsurf -and -not $Cursor -and -not $Claude -and -not $All) {
    Write-Host "Which IDE(s) do you want to install for?"
    Write-Host "  1) Windsurf / Cascade"
    Write-Host "  2) Cursor"
    Write-Host "  3) Claude Code"
    Write-Host "  4) All of the above"
    Write-Host "  5) Just clone the repo (manual setup)"
    Write-Host ""
    $choice = Read-Host "Choose [1-5]"
    switch ($choice) {
        "1" { $Windsurf = $true }
        "2" { $Cursor = $true }
        "3" { $Claude = $true }
        "4" { $All = $true }
        "5" { }
        default { Write-Host "Invalid choice" -ForegroundColor Red; exit 1 }
    }
}

if ($All) {
    $Windsurf = $true
    $Cursor = $true
    $Claude = $true
}

# ─── Clone or use local ─────────────────────────────────

$TempDir = Join-Path $env:TEMP "pyth-entropy-install-$(Get-Random)"
$SkillSource = Join-Path $TempDir $SkillName

Write-Host "Cloning Pyth Entropy skill..." -ForegroundColor Cyan
try {
    git clone --depth 1 $RepoUrl $SkillSource 2>$null
} catch {
    Write-Host "Git clone failed. Using local copy..." -ForegroundColor Yellow
    $SkillSource = $PSScriptRoot
}

# ─── Windsurf Install ────────────────────────────────────

if ($Windsurf) {
    Write-Host ""
    Write-Host "Installing for Windsurf/Cascade..." -ForegroundColor Cyan

    $WindsurfSkills = Join-Path $env:USERPROFILE ".codeium\windsurf\skills"
    if (-not (Test-Path $WindsurfSkills)) {
        New-Item -ItemType Directory -Path $WindsurfSkills -Force | Out-Null
    }

    $Dest = Join-Path $WindsurfSkills $SkillName
    if (Test-Path $Dest) {
        Write-Host "Updating existing installation..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $Dest
    }

    Copy-Item -Recurse $SkillSource $Dest
    Write-Host "  Installed to $Dest" -ForegroundColor Green
    Write-Host "  Windsurf will auto-discover the skill via SKILL.md"
}

# ─── Cursor Install ──────────────────────────────────────

if ($Cursor) {
    Write-Host ""
    Write-Host "Installing for Cursor..." -ForegroundColor Cyan

    $Target = if ($Project) { $Project } else { Get-Location }

    if (-not (Test-Path $Target)) {
        Write-Host "Project directory not found: $Target" -ForegroundColor Red
        Write-Host "Use -Project 'C:\path\to\your\project'"
    } else {
        # Copy .cursorrules
        Copy-Item (Join-Path $SkillSource ".cursorrules") (Join-Path $Target ".cursorrules") -Force
        Write-Host "  Copied .cursorrules" -ForegroundColor Green

        # Copy .cursor/rules/
        $CursorRulesDir = Join-Path $Target ".cursor\rules"
        if (-not (Test-Path $CursorRulesDir)) {
            New-Item -ItemType Directory -Path $CursorRulesDir -Force | Out-Null
        }
        Copy-Item (Join-Path $SkillSource ".cursor\rules\pyth-entropy.md") (Join-Path $CursorRulesDir "pyth-entropy.md") -Force
        Write-Host "  Copied .cursor/rules/pyth-entropy.md" -ForegroundColor Green
    }
}

# ─── Claude Code Install ─────────────────────────────────

if ($Claude) {
    Write-Host ""
    Write-Host "Installing for Claude Code..." -ForegroundColor Cyan

    $Target = if ($Project) { $Project } else { Get-Location }

    if (-not (Test-Path $Target)) {
        Write-Host "Project directory not found: $Target" -ForegroundColor Red
    } else {
        # Copy .claude directory
        $ClaudeDir = Join-Path $Target ".claude\commands"
        if (-not (Test-Path $ClaudeDir)) {
            New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
        }
        Copy-Item (Join-Path $SkillSource ".claude\CLAUDE.md") (Join-Path $Target ".claude\CLAUDE.md") -Force
        Copy-Item (Join-Path $SkillSource ".claude\commands\entropy.md") (Join-Path $ClaudeDir "entropy.md") -Force
        Write-Host "  Copied .claude/CLAUDE.md and commands/entropy.md" -ForegroundColor Green

        # Copy full skill for reference
        $SkillDest = Join-Path $Target ".claude\skills\$SkillName"
        if (-not (Test-Path $SkillDest)) {
            New-Item -ItemType Directory -Path $SkillDest -Force | Out-Null
        }
        Copy-Item -Recurse (Join-Path $SkillSource "references") $SkillDest -Force
        Copy-Item -Recurse (Join-Path $SkillSource "assets") $SkillDest -Force
        Copy-Item (Join-Path $SkillSource "SKILL.md") (Join-Path $SkillDest "SKILL.md") -Force
        Write-Host "  Copied full skill to $SkillDest" -ForegroundColor Green

        Write-Host "  Use /entropy command in Claude Code to integrate"
    }
}

# ─── Cleanup ─────────────────────────────────────────────

if ($SkillSource -ne $PSScriptRoot -and (Test-Path $TempDir)) {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "  Pyth Entropy skill installed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host '  1. Open your project in your IDE'
Write-Host '  2. Tell your AI: "Add Pyth Entropy to my project"'
Write-Host '  3. It will auto-detect your stack and generate adapted code'
Write-Host ""
Write-Host "Docs: https://docs.pyth.network/entropy" -ForegroundColor Cyan
