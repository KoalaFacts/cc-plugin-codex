#!/usr/bin/env pwsh
# Test-Plugin.ps1 — smoke test for cc-plugin-codex.
#
# Runs static checks on the plugin layout and (optionally) end-to-end
# checks against a real `claude` binary in a temporary fixture repo.
#
# Usage:
#   pwsh ./scripts/Test-Plugin.ps1                 # static checks only
#   pwsh ./scripts/Test-Plugin.ps1 -E2E            # also run e2e (needs `claude` on PATH)
#   pwsh ./scripts/Test-Plugin.ps1 -E2E -KeepTmp   # don't delete the fixture repo after

[CmdletBinding()]
param(
  [switch]$E2E,
  [switch]$KeepTmp
)

$ErrorActionPreference = 'Stop'
$script:Failures = @()

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    $script:Failures += $Message
    Write-Host "  FAIL  $Message" -ForegroundColor Red
  } else {
    Write-Host "  ok    $Message" -ForegroundColor Green
  }
}

function Section {
  param([string]$Name)
  Write-Host ""
  Write-Host "=== $Name ===" -ForegroundColor Cyan
}

$root = (Resolve-Path "$PSScriptRoot/..").Path
Push-Location $root
try {
  Section "Static layout"
  Assert-True (Test-Path ".codex-plugin/plugin.json")     "manifest exists"
  Assert-True (Test-Path "skills/claude-setup/SKILL.md")    "skill: claude-setup"
  Assert-True (Test-Path "skills/claude-plan/SKILL.md")     "skill: claude-plan"
  Assert-True (Test-Path "skills/claude-implement/SKILL.md") "skill: claude-implement"
  Assert-True (Test-Path "skills/claude-execute/SKILL.md")   "skill: claude-execute"
  Assert-True (Test-Path "skills/claude-review/SKILL.md")    "skill: claude-review"
  Assert-True (Test-Path "skills/claude-rescue/SKILL.md")    "skill: claude-rescue"
  foreach ($p in @('default','evil','security','perf','api-design')) {
    Assert-True (Test-Path "personas/$p.md") "persona: $p"
  }
  foreach ($s in @('planner','implementer','executor')) {
    Assert-True (Test-Path "system-prompts/$s.md") "system-prompt: $s"
  }
  Assert-True (Test-Path ".mcp.json")     ".mcp.json exists"
  Assert-True (Test-Path "README.md")     "README.md exists"

  Section "Manifest parses"
  try {
    $manifest = Get-Content ".codex-plugin/plugin.json" -Raw | ConvertFrom-Json
    Assert-True ($manifest.name -eq "cc-plugin-codex") "manifest name == cc-plugin-codex"
    Assert-True ($null -ne $manifest.version)         "manifest has version"
    Assert-True ($manifest.skills -eq "./skills/")    "manifest skills points to ./skills/"
  } catch {
    Assert-True $false "manifest JSON parse: $($_.Exception.Message)"
  }

  Section "Skill frontmatter"
  Get-ChildItem -Path skills -Recurse -Filter SKILL.md | ForEach-Object {
    $first = Get-Content $_.FullName -TotalCount 8 -Raw
    Assert-True ($first.StartsWith("---")) "$($_.FullName) starts with frontmatter"
    Assert-True ($first -match "(?m)^name:\s*\S+") "$($_.FullName) has name"
    Assert-True ($first -match "(?m)^description:\s*\S+") "$($_.FullName) has description"
  }

  if ($E2E) {
    Section "E2E (requires `claude` on PATH)"
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
      $script:Failures += "claude not on PATH — skipping e2e"
      Write-Host "  SKIP  claude not on PATH" -ForegroundColor Yellow
    } else {
      $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "cc-plugin-codex-e2e-$(Get-Random)"
      New-Item -ItemType Directory -Path $tmp | Out-Null
      Push-Location $tmp
      try {
        git init -q
        git config user.email "test@example.com"
        git config user.name  "Test"
        Set-Content -Path README.md -Value "# fixture`n"
        git add README.md; git commit -q -m "init"
        Set-Content -Path README.md -Value "# fixture`n`nA new line.`n"
        git add README.md; git commit -q -m "edit"

        $prompt = "Reply with a one-paragraph review of the diff between HEAD~1 and HEAD."
        $diff   = git diff --no-color HEAD~1...HEAD
        $full   = "$prompt`n`n```diff`n$diff`n```"

        $tmpPrompt = Join-Path $tmp "prompt.txt"
        Set-Content -Path $tmpPrompt -Value $full
        $json = Get-Content $tmpPrompt -Raw | claude -p --output-format json --max-turns 5

        try {
          $parsed = $json | ConvertFrom-Json
          Assert-True ($null -ne $parsed.result -and $parsed.result.Length -gt 0) "claude -p returned non-empty result"
        } catch {
          Assert-True $false "claude -p output is not valid JSON: $($_.Exception.Message)"
        }
      } finally {
        Pop-Location
        if (-not $KeepTmp) {
          Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        } else {
          Write-Host "  kept fixture at $tmp" -ForegroundColor Yellow
        }
      }
    }
  }

  Write-Host ""
  if ($script:Failures.Count -gt 0) {
    Write-Host "FAILED ($($script:Failures.Count))" -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
  } else {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
  }
} finally {
  Pop-Location
}
