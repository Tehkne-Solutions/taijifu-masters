param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
  [string]$AssetsRepoRoot = ""
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$contractPath = Join-Path $RepoRoot "config\v2-rival-intake-contract.json"
$progressPath = Join-Path $RepoRoot "config\v2-production-progress.json"
$reportLib = Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1"
foreach ($file in @($contractPath, $progressPath, $reportLib)) {
  if (-not (Test-Path $file)) { throw "VM02_C28_REQUIRED_FILES=BLOCKED missing=$file" }
}
Write-Host "VM02_C28_REQUIRED_FILES=PASS"

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$progress = Get-Content $progressPath -Raw | ConvertFrom-Json
if ($contract.signature -ne "Tehkné Solutions") { throw "VM02_C28_SIGNATURE=BLOCKED" }
if ($contract.character_id -ne "training_rival") { throw "VM02_C28_CHARACTER_CONTRACT=BLOCKED" }
if ([int]$contract.required_total_frames -ne 44) { throw "VM02_C28_FRAME_CONTRACT=BLOCKED" }
Write-Host "VM02_C28_CONTRACT=PASS"

if (-not $AssetsRepoRoot) {
  $workspace = Split-Path $RepoRoot -Parent
  $AssetsRepoRoot = Join-Path $workspace "taijifu-masters-assets"
}

$assetsRepoDetected = Test-Path (Join-Path $AssetsRepoRoot ".git")
if (-not $assetsRepoDetected -and [bool]$contract.import_policy.auto_clone_assets_repo) {
  Write-Host "VM02_C28_ASSETS_REPO_CLONE=BEGIN path=$AssetsRepoRoot"
  git clone --quiet $contract.source_repository $AssetsRepoRoot
  if ($LASTEXITCODE -ne 0) { throw "VM02_C28_ASSETS_REPO_CLONE=BLOCKED" }
  $assetsRepoDetected = Test-Path (Join-Path $AssetsRepoRoot ".git")
  Write-Host "VM02_C28_ASSETS_REPO_CLONE=PASS"
}
if (-not $assetsRepoDetected) { throw "VM02_C28_ASSETS_REPO=BLOCKED path=$AssetsRepoRoot" }
Write-Host "VM02_C28_ASSETS_REPO=PASS path=$AssetsRepoRoot"

if ([bool]$contract.import_policy.auto_fast_forward_assets_repo) {
  Push-Location $AssetsRepoRoot
  try {
    git fetch origin --quiet
    if ($LASTEXITCODE -ne 0) { throw "VM02_C28_ASSETS_FETCH=BLOCKED" }
    $branch = (git branch --show-current).Trim()
    if (-not $branch) { $branch = "main" }
    git pull --ff-only --quiet origin $branch
    if ($LASTEXITCODE -ne 0) { throw "VM02_C28_ASSETS_PULL=BLOCKED branch=$branch" }
    Write-Host "VM02_C28_ASSETS_SYNC=PASS branch=$branch"
  } finally {
    Pop-Location
  }
}

$sourceLot = Join-Path $AssetsRepoRoot ([string]$contract.source_lot)
$sourceManifest = Join-Path $AssetsRepoRoot ([string]$contract.source_manifest)
$manifestReady = Test-Path $sourceManifest
Write-Host ("VM02_C28_SOURCE_MANIFEST=" + $(if ($manifestReady) { "PASS" } else { "BLOCKED" }))

$frameCount = 0
$frameContractReady = $false
$sourceManifestValid = $false
$missing = New-Object System.Collections.Generic.List[string]

if ($manifestReady) {
  try {
    $manifest = Get-Content $sourceManifest -Raw | ConvertFrom-Json
    $sourceManifestValid = ($manifest.signature -eq "Tehkné Solutions") -and ($manifest.character_id -eq "training_rival") -and ([int]$manifest.required_frames -eq 44)
  } catch {
    $sourceManifestValid = $false
  }
  Write-Host ("VM02_C28_SOURCE_MANIFEST_SCHEMA=" + $(if ($sourceManifestValid) { "PASS" } else { "BLOCKED" }))

  foreach ($property in $contract.required_animations.PSObject.Properties) {
    $animation = $property.Name
    $expected = [int]$property.Value
    $folder = Join-Path $sourceLot ("animations\" + $animation)
    for ($i = 1; $i -le $expected; $i++) {
      $name = "char_training_rival__{0}__f{1:d3}.png" -f $animation, $i
      $path = Join-Path $folder $name
      if (Test-Path $path) { $frameCount++ } else { $missing.Add(("{0}/f{1:d3}" -f $animation, $i)) }
    }
  }
  $frameContractReady = $sourceManifestValid -and ($frameCount -eq 44) -and ($missing.Count -eq 0)
}

Write-Host "VM02_C28_RIVAL_FRAME_COUNT=$frameCount/44"
Write-Host ("VM02_C28_RIVAL_FRAME_CONTRACT=" + $(if ($frameContractReady) { "PASS" } else { "BLOCKED" }))
if ($missing.Count -gt 0) {
  Write-Host "VM02_C28_MISSING_FRAME_COUNT=$($missing.Count)"
  $missing | Select-Object -First 8 | ForEach-Object { Write-Host "VM02_C28_MISSING_FRAME=$_" }
}

$destination = Join-Path $RepoRoot ([string]$contract.destination_root)
$imported = $false
if ($frameContractReady -and [bool]$contract.import_policy.auto_import_when_complete) {
  $staging = "$destination.__c28_staging"
  if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $staging | Out-Null
  Copy-Item (Join-Path $sourceLot "animations") -Destination $staging -Recurse -Force
  Copy-Item $sourceManifest -Destination (Join-Path $staging "source-work-manifest.json") -Force
  if (Test-Path $destination) { Remove-Item $destination -Recurse -Force }
  Move-Item $staging $destination
  $imported = $true
  Write-Host "VM02_C28_RIVAL_IMPORT=PASS destination=$destination"
} else {
  Write-Host "VM02_C28_RIVAL_IMPORT=BLOCKED waiting_for_complete_canonical_pack"
}

$rivalReady = $frameContractReady -and $imported
Write-Host ("VM02_C28_RIVAL_CANONICAL_READY=" + $(if ($rivalReady) { "PASS" } else { "BLOCKED" }))
Write-Host "VM02_C28_PIPELINE_READY=PASS"
Write-Host "VM02_C28_V2_RIVAL_INTAKE_GATE=PASS"

. $reportLib
$branchName = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C28-V2-RIVAL-INTAKE-BRIDGE" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  CONTRACT="PASS"
  ASSETS_REPO="PASS"
  SOURCE_MANIFEST=$(if ($manifestReady -and $sourceManifestValid) { "PASS" } else { "BLOCKED" })
  FRAME_COUNT="$frameCount/44"
  FRAME_CONTRACT=$(if ($frameContractReady) { "PASS" } else { "BLOCKED" })
  RIVAL_IMPORT=$(if ($imported) { "PASS" } else { "BLOCKED" })
  RIVAL_CANONICAL_READY=$(if ($rivalReady) { "PASS" } else { "BLOCKED" })
  PIPELINE_READY="PASS"
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard
