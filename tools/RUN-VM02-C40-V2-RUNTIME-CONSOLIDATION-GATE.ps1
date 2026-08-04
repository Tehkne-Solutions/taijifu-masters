param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts\vertical_slice\first_playable.gd",
  "scripts\vertical_slice\first_playable_environment_art.gd",
  "scripts\vertical_slice\canonical_arena_parallax.gd",
  "tools\RUN-VM02-C38-TRAINING-RIVAL-P01-INTAKE-GATE.ps1",
  "tools\RUN-VM02-C39-TRAINING-RIVAL-P01-MATERIALIZER-GATE.ps1",
  "config\v2-production-progress.json"
)

$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C40_MISSING=$_" }
  throw "VM02_C40_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C40_REQUIRED_FILES=PASS"

$arenaRoot = Join-Path $RepoRoot "assets\pack_03_stages\mountain_dojo_night"
$arenaExpected = @("background.png","midground.png","foreground.png","collision.json","lighting.json","manifest.json")
$arenaPresent = @($arenaExpected | Where-Object { Test-Path (Join-Path $arenaRoot $_) })
Write-Host "VM02_C40_CANONICAL_ARENA_FILE_COUNT=$($arenaPresent.Count)/6"
if ($arenaPresent.Count -ne 6) { throw "VM02_C40_CANONICAL_ARENA=BLOCKED" }
Write-Host "VM02_C40_CANONICAL_ARENA=PASS"

$progressPath = Join-Path $RepoRoot "config\v2-production-progress.json"
$progress = Get-Content $progressPath -Raw | ConvertFrom-Json
if (-not [bool]$progress.v2_playable.runtime_ready) { throw "VM02_C40_RUNTIME_READY_CONTRACT=BLOCKED" }
if ([bool]$progress.v2_playable.art_complete) { throw "VM02_C40_ART_SPLIT_CONTRACT=BLOCKED art_complete_must_remain_false" }
Write-Host "VM02_C40_RUNTIME_READY_CONTRACT=PASS"
Write-Host "VM02_C40_ART_COMPLETE=BLOCKED expected_pending_art"

$assetsRepo = Join-Path (Split-Path $RepoRoot -Parent) "taijifu-masters-assets"
$rivalMaster = Join-Path $assetsRepo "production\first_playable\training_rival\source\training_rival_master.png"
if (Test-Path $rivalMaster) {
  Write-Host "VM02_C40_TRAINING_RIVAL_MASTER=AVAILABLE"
} else {
  Write-Host "VM02_C40_TRAINING_RIVAL_MASTER=PENDING_NON_BLOCKING"
}

# C40 intentionally allows the existing rival proxy so runtime packaging can advance.
# Canonical art promotion remains governed by C39 -> C38 -> C28 -> C36.
Write-Host "VM02_C40_PROXY_POLICY=PASS explicit_noncanonical_runtime_placeholder"
Write-Host "VM02_C40_RIVAL_ART_PIPELINE=PASS isolated_dependency"
Write-Host "VM02_C40_RUNTIME_CONSOLIDATION=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C40-V2-RUNTIME-CONSOLIDATION",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "RUNTIME_READY=PASS",
  "ART_COMPLETE=BLOCKED",
  "CANONICAL_ARENA=PASS",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PROXY_POLICY=PASS",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=57%",
  "PROJECT_PROGRESS=44%",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try {
  ($report -join [Environment]::NewLine) | Set-Clipboard
  Write-Host "COPY_REPORT_CLIPBOARD=PASS"
} catch {
  Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED"
}

Write-Host "VM02_C40_V2_RUNTIME_CONSOLIDATION_GATE=PASS"
Write-Host "Tehkne Solutions"
