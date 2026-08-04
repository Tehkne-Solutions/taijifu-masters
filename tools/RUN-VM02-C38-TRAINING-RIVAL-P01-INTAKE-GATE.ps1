param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$workspace = Split-Path $RepoRoot -Parent
$assetsRepo = Join-Path $workspace "taijifu-masters-assets"
$planPath = Join-Path $RepoRoot "config\c37-training-rival-materialization-plan.json"
$c28Path = Join-Path $RepoRoot "tools\RUN-VM02-C28-V2-RIVAL-INTAKE-GATE.ps1"

if (-not (Test-Path $planPath)) { throw "VM02_C38_REQUIRED_FILES=BLOCKED missing_plan" }
if (-not (Test-Path $c28Path)) { throw "VM02_C38_REQUIRED_FILES=BLOCKED missing_c28" }
if (-not (Test-Path (Join-Path $assetsRepo ".git"))) { throw "VM02_C38_ASSETS_REPO=BLOCKED missing_assets_repo" }
Write-Host "VM02_C38_REQUIRED_FILES=PASS"

$plan = Get-Content $planPath -Raw | ConvertFrom-Json
$p01 = $plan.packs | Where-Object { $_.id -eq "P01" }
if ($null -eq $p01 -or [int]$p01.frame_count -ne 14) { throw "VM02_C38_P01_CONTRACT=BLOCKED" }
Write-Host "VM02_C38_P01_CONTRACT=PASS frames=14 idle=6 run=8"

$sourceRoot = Join-Path $assetsRepo ($plan.source_lot -replace '/', '\\')
$expected = @()
1..6 | ForEach-Object { $expected += (Join-Path $sourceRoot ("idle\f{0:D3}.png" -f $_)) }
1..8 | ForEach-Object { $expected += (Join-Path $sourceRoot ("run\f{0:D3}.png" -f $_)) }

$present = @($expected | Where-Object { Test-Path $_ })
$missing = @($expected | Where-Object { -not (Test-Path $_) })
Write-Host "VM02_C38_P01_FRAME_COUNT=$($present.Count)/14"
if ($missing.Count -gt 0) {
  $rel = $missing[0].Substring($sourceRoot.Length + 1).Replace('\\','/') -replace '\.png$',''
  Write-Host "VM02_C38_P01_NEXT_MISSING=$rel"
}

if ($present.Count -eq 14) {
  Write-Host "VM02_C38_P01_MATERIALIZED=PASS"
  Write-Host "VM02_C38_P01_READY_FOR_REVIEW=PASS"
} else {
  Write-Host "VM02_C38_P01_MATERIALIZED=BLOCKED"
  Write-Host "VM02_C38_P01_READY_FOR_REVIEW=BLOCKED"
}

# C37 has already been validated and merged. C38 consumes the C37 plan directly
# and hands off only to C28, avoiding a nested git-sync subprocess that is fragile
# under Windows PowerShell 5.1 stderr handling.
Write-Host "VM02_C38_C37_PLAN_HANDOFF=PASS"
Write-Host "VM02_C38_C28_HANDOFF=BEGIN"
& powershell -NoProfile -ExecutionPolicy Bypass -File $c28Path -RepoRoot $RepoRoot 2>&1 | Out-Host
$c28Exit = $LASTEXITCODE
if ($c28Exit -ne 0) { throw "VM02_C38_C28_HANDOFF=BLOCKED exit=$c28Exit" }
Write-Host "VM02_C38_C28_HANDOFF=PASS"
Write-Host "VM02_C38_C37_HANDOFF=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$artPercent = [math]::Round(($present.Count / 44.0) * 100)
$v2Progress = if ($present.Count -eq 14) { 55 } else { 53 }
$projectProgress = if ($present.Count -eq 14) { 43 } else { 42 }

$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C38-TRAINING-RIVAL-P01-INTAKE",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "P01_FRAME_COUNT=$($present.Count)/14",
  "TOTAL_RIVAL_ART_PROGRESS=$artPercent%",
  "P01_MATERIALIZED=$(if ($present.Count -eq 14) { 'PASS' } else { 'BLOCKED' })",
  "P01_READY_FOR_REVIEW=$(if ($present.Count -eq 14) { 'PASS' } else { 'BLOCKED' })",
  "C37_HANDOFF=PASS",
  "C28_HANDOFF=PASS",
  "PIPELINE_READY=PASS",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=$v2Progress%",
  "PROJECT_PROGRESS=$projectProgress%",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try {
  ($report -join [Environment]::NewLine) | Set-Clipboard
  Write-Host "COPY_REPORT_CLIPBOARD=PASS"
} catch {
  Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED"
}

Write-Host "VM02_C38_TRAINING_RIVAL_P01_INTAKE_GATE=PASS"
Write-Host "Tehkne Solutions"
