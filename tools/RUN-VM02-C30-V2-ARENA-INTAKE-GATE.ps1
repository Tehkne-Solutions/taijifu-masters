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
if (-not $contract.source_release_sha256) { throw "VM02_C30_RELEASE_SHA=BLOCKED reason=missing" }
if (-not $contract.source_content_sha256) { throw "VM02_C30_CONTENT_SHA=BLOCKED reason=missing" }
if (-not $contract.source_snapshot_freeze) { throw "VM02_C30_SNAPSHOT_FREEZE=BLOCKED reason=missing_path" }
if (-not [bool]$contract.import_policy.immutable_source_ref) { throw "VM02_C30_SOURCE_PIN=BLOCKED reason=mutable_policy" }
if (-not [bool]$contract.import_policy.verify_source_commit) { throw "VM02_C30_SOURCE_PIN=BLOCKED reason=commit_verification_disabled" }
if (-not [bool]$contract.import_policy.verify_snapshot_freeze) { throw "VM02_C30_SNAPSHOT_FREEZE=BLOCKED reason=freeze_verification_disabled" }
if ([bool]$contract.import_policy.auto_fast_forward_assets_repo) { throw "VM02_C30_SOURCE_PIN=BLOCKED reason=fast_forward_forbidden" }
if ([int]$contract.snapshot_contract.lian_wu_frames -ne 45) { throw "VM02_C30_SNAPSHOT_CONTRACT=BLOCKED reason=lian_frames" }
if ([int]$contract.snapshot_contract.training_rival_frames -ne 44) { throw "VM02_C30_SNAPSHOT_CONTRACT=BLOCKED reason=rival_frames" }
if ([int]$contract.snapshot_contract.fighter_frames -ne 89) { throw "VM02_C30_SNAPSHOT_CONTRACT=BLOCKED reason=fighter_frames" }
if ([int]$contract.snapshot_contract.stage_layers -ne 3) { throw "VM02_C30_SNAPSHOT_CONTRACT=BLOCKED reason=stage_layers" }
Write-Host "VM02_C30_CONTRACT=PASS"
Write-Host "VM02_C30_SOURCE_PIN_CONTRACT=PASS ref=$($contract.source_ref) commit=$($contract.source_commit)"
Write-Host "VM02_C30_SNAPSHOT_CONTRACT=PASS fighters=89 animations=20 stage_layers=3"

if (-not $AssetsRepoRoot) {
  $workspace = Split-Path $RepoRoot -Parent
  $AssetsRepoRoot = Join-Path $workspace "taijifu-masters-assets"
}

# Never smudge the complete Asset Vault during clone/checkout. C30 only needs
# the three arena PNGs materialized; fighter matrices are verified structurally.
$previousSkipSmudge = $env:GIT_LFS_SKIP_SMUDGE
$env:GIT_LFS_SKIP_SMUDGE = "1"

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

  $stageInclude = ([string]$contract.source_root).Replace('\','/') + "/*.png"
  git lfs pull --include=$stageInclude --exclude=""
  if ($LASTEXITCODE -ne 0) { throw "VM02_C30_STAGE_LFS=BLOCKED include=$stageInclude" }
  Write-Host "VM02_C30_STAGE_LFS=PASS files=background.png,midground.png,foreground.png"
} finally {
  Pop-Location
  if ($null -eq $previousSkipSmudge) {
    Remove-Item Env:GIT_LFS_SKIP_SMUDGE -ErrorAction SilentlyContinue
  } else {
    $env:GIT_LFS_SKIP_SMUDGE = $previousSkipSmudge
  }
}

$freezePath = Join-Path $AssetsRepoRoot ([string]$contract.source_snapshot_freeze)
if (-not (Test-Path $freezePath)) { throw "VM02_C30_SNAPSHOT_FREEZE=BLOCKED reason=file_missing path=$freezePath" }
$freeze = Get-Content $freezePath -Raw | ConvertFrom-Json
$freezeValid = (
  ($freeze.signature -eq "Tehkné Solutions") -and
  ($freeze.tag -eq [string]$contract.source_ref) -and
  ($freeze.filename -eq [string]$contract.source_release_asset) -and
  ($freeze.sha256 -eq [string]$contract.source_release_sha256) -and
  ($freeze.content_sha256 -eq [string]$contract.source_content_sha256) -and
  ([int]$freeze.fighter_frames -eq 89) -and
  ([int]$freeze.fighter_animations -eq 20) -and
  ([int]$freeze.stage_layers -eq 3)
)
if (-not $freezeValid) { throw "VM02_C30_SNAPSHOT_FREEZE=BLOCKED reason=contract_mismatch" }
Write-Host "VM02_C30_SNAPSHOT_FREEZE=PASS sha256=$($freeze.sha256) content_sha256=$($freeze.content_sha256)"

$lianRoot = Join-Path $AssetsRepoRoot ([string]$contract.snapshot_contract.lian_wu_root)
$rivalRoot = Join-Path $AssetsRepoRoot ([string]$contract.snapshot_contract.training_rival_root)
$lianManifestPath = Join-Path $lianRoot "work-manifest.json"
$rivalManifestPath = Join-Path $rivalRoot "work-manifest.json"
foreach ($required in @($lianManifestPath, $rivalManifestPath)) {
  if (-not (Test-Path $required)) { throw "VM02_C30_SNAPSHOT_FIGHTER=BLOCKED missing=$required" }
}
$lianManifest = Get-Content $lianManifestPath -Raw | ConvertFrom-Json
$rivalManifest = Get-Content $rivalManifestPath -Raw | ConvertFrom-Json
$lianCount = @(Get-ChildItem (Join-Path $lianRoot "animations") -Recurse -File -Filter "*.png").Count
$rivalCount = @(Get-ChildItem (Join-Path $rivalRoot "animations") -Recurse -File -Filter "*.png").Count
$lianAnimations = @($lianManifest.animations.PSObject.Properties).Count
$rivalAnimations = @($rivalManifest.animations.PSObject.Properties).Count
$lianValid = (
  ($lianManifest.signature -eq "Tehkné Solutions") -and
  ([int]$lianManifest.required_frames -eq 45) -and
  ($lianManifest.release_tag -eq "assets-pack-01-v2.0.0") -and
  ($lianManifest.release_sha256 -eq "f000de1d3a0ca452bcae88f628264a16fcb57ca5c31791dc46525e175a0cb34c") -and
  ($lianCount -eq 45) -and
  ($lianAnimations -eq 10)
)
$rivalValid = (
  ($rivalManifest.signature -eq "Tehkné Solutions") -and
  ([int]$rivalManifest.required_frames -eq 44) -and
  ($rivalCount -eq 44) -and
  ($rivalAnimations -eq 10)
)
if (-not $lianValid) { throw "VM02_C30_SNAPSHOT_LIAN=BLOCKED frames=$lianCount animations=$lianAnimations" }
if (-not $rivalValid) { throw "VM02_C30_SNAPSHOT_RIVAL=BLOCKED frames=$rivalCount animations=$rivalAnimations" }
if (($lianCount + $rivalCount) -ne 89) { throw "VM02_C30_SNAPSHOT_FIGHTER_FRAME_COUNT=BLOCKED count=$($lianCount + $rivalCount)" }
Write-Host "VM02_C30_SNAPSHOT_LIAN=PASS frames=45 animations=10"
Write-Host "VM02_C30_SNAPSHOT_RIVAL=PASS frames=44 animations=10"
Write-Host "VM02_C30_SNAPSHOT_FIGHTER_FRAME_COUNT=89/89"

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

function Test-PngSignature([string]$Path) {
  if (-not (Test-Path $Path)) { return $false }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 8) { return $false }
  $signature = @(0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A)
  for ($i = 0; $i -lt 8; $i++) {
    if ($bytes[$i] -ne $signature[$i]) { return $false }
  }
  return $true
}
foreach ($png in @("background.png", "midground.png", "foreground.png")) {
  if (-not (Test-PngSignature (Join-Path $sourceRoot $png))) {
    throw "VM02_C30_STAGE_LFS=BLOCKED reason=not_materialized file=$png"
  }
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
if (-not $manifestValid) { throw "VM02_C30_SOURCE_MANIFEST_SCHEMA=BLOCKED" }
Write-Host "VM02_C30_SOURCE_MANIFEST_SCHEMA=PASS"
Write-Host "VM02_C30_SNAPSHOT_STAGE=PASS layers=3 arena=mountain_dojo_night art_final=true canonical_ready=true"
Write-Host "VM02_C30_FIRST_PLAYABLE_SNAPSHOT=PASS"

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
if (-not $arenaReady) { throw "VM02_C30_ARENA_CANONICAL_READY=BLOCKED" }
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
Write-TehkneGateReport -Gate "VM02-C30-FIRST-PLAYABLE-SNAPSHOT-INTAKE" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  CONTRACT="PASS"
  SOURCE_REF=[string]$contract.source_ref
  SOURCE_COMMIT=[string]$contract.source_commit
  SOURCE_RELEASE_SHA256=[string]$contract.source_release_sha256
  SOURCE_CONTENT_SHA256=[string]$contract.source_content_sha256
  SOURCE_PIN="PASS"
  SNAPSHOT_FREEZE="PASS"
  SNAPSHOT_LIAN="45/45"
  SNAPSHOT_RIVAL="44/44"
  SNAPSHOT_FIGHTERS="89/89"
  SNAPSHOT_STAGE="3/3"
  ASSETS_REPO="PASS"
  SOURCE_MANIFEST="PASS"
  FILE_COUNT="$($contract.required_files.Count - $missing.Count)/$($contract.required_files.Count)"
  FILE_CONTRACT=$(if ($filesReady) { "PASS" } else { "BLOCKED" })
  ARENA_IMPORT=$(if ($imported) { "PASS" } else { "BLOCKED" })
  ARENA_CANONICAL_READY=$(if ($arenaReady) { "PASS" } else { "BLOCKED" })
  PIPELINE_READY="PASS"
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard
