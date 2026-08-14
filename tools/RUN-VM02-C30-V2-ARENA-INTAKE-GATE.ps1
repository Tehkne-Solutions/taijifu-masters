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
if (-not $contract.source_ref) { throw "VM02_C30_SOURCE_REF=BLOCKED reason=missing" }
if (-not $contract.source_commit) { throw "VM02_C30_SOURCE_COMMIT=BLOCKED reason=missing" }
if (-not [bool]$contract.import_policy.immutable_source_ref) { throw "VM02_C30_SOURCE_PIN=BLOCKED reason=mutable_policy" }
if (-not [bool]$contract.import_policy.verify_source_commit) { throw "VM02_C30_SOURCE_PIN=BLOCKED reason=commit_verification_disabled" }
if ([bool]$contract.import_policy.auto_fast_forward_assets_repo) { throw "VM02_C30_SOURCE_PIN=BLOCKED reason=fast_forward_forbidden" }
Write-Host "VM02_C30_CONTRACT=PASS"
Write-Host "VM02_C30_SOURCE_PIN_CONTRACT=PASS ref=$($contract.source_ref) commit=$($contract.source_commit)"

if (-not $AssetsRepoRoot) {
  $workspace = Split-Path $RepoRoot -Parent
  $AssetsRepoRoot = Join-Path $workspace "taijifu-masters-assets"
}

$assetsRepoDetected = Test-Path (Join-Path $AssetsRepoRoot ".git")
if (-not $assetsRepoDetected -and [bool]$contract.import_policy.auto_clone_assets_repo) {
  Write-Host "VM02_C30_ASSETS_REPO_CLONE=BEGIN path=$AssetsRepoRoot"
  git clone --quiet --no-checkout $contract.source_repository $AssetsRepoRoot
  if ($LASTEXITCODE -ne 0) { throw "VM02_C30_ASSETS_REPO_CLONE=BLOCKED" }
  $assetsRepoDetected = Test-Path (Join-Path $AssetsRepoRoot ".git")
  Write-Host "VM02_C30_ASSETS_REPO_CLONE=PASS"
}
if (-not $assetsRepoDetected) { throw "VM02_C30_ASSETS_REPO=BLOCKED path=$AssetsRepoRoot" }
Write-Host "VM02_C30_ASSETS_REPO=PASS path=$AssetsRepoRoot"

Push-Location $AssetsRepoRoot
try {
  git fetch origin --tags --quiet
  if ($LASTEXITCODE -ne 0) { throw "VM02_C30_ASSETS_FETCH=BLOCKED" }

  $resolved = (git rev-list -n 1 ([string]$contract.source_ref)).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $resolved) { throw "VM02_C30_SOURCE_REF=BLOCKED ref=$($contract.source_ref)" }
  if ($resolved -ne [string]$contract.source_commit) {
    throw "VM02_C30_SOURCE_PIN=BLOCKED reason=tag_commit_mismatch resolved=$resolved expected=$($contract.source_commit)"
  }

  git checkout --detach --quiet ([string]$contract.source_commit)
  if ($LASTEXITCODE -ne 0) { throw "VM02_C30_SOURCE_CHECKOUT=BLOCKED commit=$($contract.source_commit)" }
  $head = (git rev-parse HEAD).Trim()
  if ($head -ne [string]$contract.source_commit) {
    throw "VM02_C30_SOURCE_PIN=BLOCKED reason=head_mismatch head=$head expected=$($contract.source_commit)"
  }
  Write-Host "VM02_C30_ASSETS_SYNC=PASS ref=$($contract.source_ref) commit=$head detached=true"
  Write-Host "VM02_C30_SOURCE_PIN=PASS"
} finally {
  Pop-Location
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
    $manifestValid = (
      ($manifest.signature -eq "Tehkné Solutions") -and
      ($manifest.arena_id -eq "mountain_dojo_night") -and
      ($manifest.version -eq "1.0.0") -and
      ($manifest.status -eq "art_final") -and
      ([bool]$manifest.promotion.canonical_ready)
    )
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
$branchNameRaw = git branch --show-current
$branchName = if ($null -eq $branchNameRaw -or [string]::IsNullOrWhiteSpace([string]$branchNameRaw)) {
  "detached"
} else {
  ([string]$branchNameRaw).Trim()
}
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C30-V2-ARENA-INTAKE-BRIDGE" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  CONTRACT="PASS"
  SOURCE_REF=[string]$contract.source_ref
  SOURCE_COMMIT=[string]$contract.source_commit
  SOURCE_PIN="PASS"
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
