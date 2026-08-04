param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
  [string]$AssetsRepoRoot = ""
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$contractPath = Join-Path $RepoRoot "config\v2-arena-intake-contract.json"
$progressPath = Join-Path $RepoRoot "config\v2-production-progress.json"
$reportLib = Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1"
foreach ($file in @($contractPath, $progressPath, $reportLib)) {
  if (-not (Test-Path $file)) { throw "VM02_C30_REQUIRED_FILES=BLOCKED missing=$file" }
}
Write-Host "VM02_C30_REQUIRED_FILES=PASS"

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$progress = Get-Content $progressPath -Raw | ConvertFrom-Json
if ($contract.signature -ne "Tehkné Solutions") { throw "VM02_C30_SIGNATURE=BLOCKED" }
if ($contract.arena_id -ne "mountain_dojo_night") { throw "VM02_C30_ARENA_CONTRACT=BLOCKED" }
if ([int]$contract.runtime_contract.parallax_layers -lt 3) { throw "VM02_C30_PARALLAX_CONTRACT=BLOCKED" }
Write-Host "VM02_C30_CONTRACT=PASS"

if (-not $AssetsRepoRoot) {
  $workspace = Split-Path $RepoRoot -Parent
  $AssetsRepoRoot = Join-Path $workspace "taijifu-masters-assets"
}

$assetsRepoDetected = Test-Path (Join-Path $AssetsRepoRoot ".git")
if (-not $assetsRepoDetected -and [bool]$contract.import_policy.auto_clone_assets_repo) {
  Write-Host "VM02_C30_ASSETS_REPO_CLONE=BEGIN path=$AssetsRepoRoot"
  git clone --quiet $contract.source_repository $AssetsRepoRoot
  if ($LASTEXITCODE -ne 0) { throw "VM02_C30_ASSETS_REPO_CLONE=BLOCKED" }
  $assetsRepoDetected = Test-Path (Join-Path $AssetsRepoRoot ".git")
  Write-Host "VM02_C30_ASSETS_REPO_CLONE=PASS"
}
if (-not $assetsRepoDetected) { throw "VM02_C30_ASSETS_REPO=BLOCKED path=$AssetsRepoRoot" }
Write-Host "VM02_C30_ASSETS_REPO=PASS path=$AssetsRepoRoot"

if ([bool]$contract.import_policy.auto_fast_forward_assets_repo) {
  Push-Location $AssetsRepoRoot
  try {
    git fetch origin --quiet
    if ($LASTEXITCODE -ne 0) { throw "VM02_C30_ASSETS_FETCH=BLOCKED" }
    $branch = (git branch --show-current).Trim()
    if (-not $branch) { $branch = "main" }
    git pull --ff-only --quiet origin $branch
    if ($LASTEXITCODE -ne 0) { throw "VM02_C30_ASSETS_PULL=BLOCKED branch=$branch" }
    Write-Host "VM02_C30_ASSETS_SYNC=PASS branch=$branch"
  } finally { Pop-Location }
}

$sourceRoot = Join-Path $AssetsRepoRoot ([string]$contract.source_root)
$sourceManifest = Join-Path $AssetsRepoRoot ([string]$contract.source_manifest)
$manifestReady = Test-Path $sourceManifest
Write-Host ("VM02_C30_SOURCE_MANIFEST=" + $(if ($manifestReady) { "PASS" } else { "BLOCKED" }))

$missing = New-Object System.Collections.Generic.List[string]
foreach ($name in $contract.required_files) {
  $path = Join-Path $sourceRoot ([string]$name)
  if (-not (Test-Path $path)) { $missing.Add([string]$name) }
}
$filesReady = $missing.Count -eq 0
Write-Host "VM02_C30_ARENA_FILE_COUNT=$($contract.required_files.Count - $missing.Count)/$($contract.required_files.Count)"
Write-Host ("VM02_C30_ARENA_FILE_CONTRACT=" + $(if ($filesReady) { "PASS" } else { "BLOCKED" }))
if ($missing.Count -gt 0) {
  Write-Host "VM02_C30_MISSING_FILE_COUNT=$($missing.Count)"
  $missing | ForEach-Object { Write-Host "VM02_C30_MISSING_FILE=$_" }
}

$manifestValid = $false
if ($manifestReady) {
  try {
    $manifest = Get-Content $sourceManifest -Raw | ConvertFrom-Json
    $manifestValid = ($manifest.signature -eq "Tehkné Solutions") -and ($manifest.arena_id -eq "mountain_dojo_night")
  } catch { $manifestValid = $false }
}
Write-Host ("VM02_C30_SOURCE_MANIFEST_SCHEMA=" + $(if ($manifestValid) { "PASS" } else { "BLOCKED" }))

$destination = Join-Path $RepoRoot ([string]$contract.destination_root)
$imported = $false
if ($filesReady -and $manifestValid -and [bool]$contract.import_policy.auto_import_when_complete) {
  $staging = "$destination.__c30_staging"
  if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $staging | Out-Null
  Copy-Item (Join-Path $sourceRoot "*") -Destination $staging -Recurse -Force
  if (Test-Path $destination) { Remove-Item $destination -Recurse -Force }
  Move-Item $staging $destination
  $imported = $true
  Write-Host "VM02_C30_ARENA_IMPORT=PASS destination=$destination"
} else {
  Write-Host "VM02_C30_ARENA_IMPORT=BLOCKED waiting_for_complete_canonical_stage"
}

$arenaReady = $filesReady -and $manifestValid -and $imported
Write-Host ("VM02_C30_ARENA_CANONICAL_READY=" + $(if ($arenaReady) { "PASS" } else { "BLOCKED" }))
Write-Host "VM02_C30_PIPELINE_READY=PASS"
Write-Host "VM02_C30_V2_ARENA_INTAKE_GATE=PASS"

. $reportLib
$branchName = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C30-V2-ARENA-INTAKE-BRIDGE" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  CONTRACT="PASS"
  ASSETS_REPO="PASS"
  SOURCE_MANIFEST=$(if ($manifestReady -and $manifestValid) { "PASS" } else { "BLOCKED" })
  FILE_COUNT="$($contract.required_files.Count - $missing.Count)/$($contract.required_files.Count)"
  FILE_CONTRACT=$(if ($filesReady) { "PASS" } else { "BLOCKED" })
  ARENA_IMPORT=$(if ($imported) { "PASS" } else { "BLOCKED" })
  ARENA_CANONICAL_READY=$(if ($arenaReady) { "PASS" } else { "BLOCKED" })
  PIPELINE_READY="PASS"
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard
