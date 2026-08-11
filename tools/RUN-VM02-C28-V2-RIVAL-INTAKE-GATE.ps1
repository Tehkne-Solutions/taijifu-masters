param(
  [string]$RepoRoot = "",
  [string]$AssetsRepoRoot = ""
)

$ErrorActionPreference = "Stop"

$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) { throw "VM02_C28_REPO_ROOT=BLOCKED script_path_unavailable" }
$scriptRoot = Split-Path -Parent $scriptPath
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
} else {
  $RepoRoot = (Resolve-Path $RepoRoot).Path
}
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) { throw "VM02_C28_REPO_ROOT=BLOCKED path=$RepoRoot" }
Set-Location $RepoRoot
Write-Host "VM02_C28_REPO_ROOT=PASS path=$RepoRoot"

# Kept only for backwards-compatible invocation. C28 is now a read-only gate over
# the already imported, revision-pinned product; re-import belongs to the Python importer.
if (-not [string]::IsNullOrWhiteSpace($AssetsRepoRoot)) {
  Write-Host "VM02_C28_ASSETS_REPO_ROOT=IGNORED legacy_parameter=true"
}

$contractPath = Join-Path $RepoRoot "config\v2-rival-intake-contract.json"
$evidencePath = Join-Path $RepoRoot "config\c28-training-rival-runtime-evidence.json"
$validatorPath = Join-Path $RepoRoot "tools\validate_training_rival_c28_import.py"
$progressPath = Join-Path $RepoRoot "config\v2-production-progress.json"
$reportLib = Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1"
foreach ($file in @($contractPath, $evidencePath, $validatorPath, $progressPath, $reportLib)) {
  if (-not (Test-Path $file -PathType Leaf)) { throw "VM02_C28_REQUIRED_FILES=BLOCKED missing=$file" }
}
Write-Host "VM02_C28_REQUIRED_FILES=PASS"

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
$progress = Get-Content $progressPath -Raw | ConvertFrom-Json
if ($contract.signature -ne "Tehkné Solutions" -or $contract.character_id -ne "training_rival" -or [int]$contract.required_total_frames -ne 44) {
  throw "VM02_C28_CONTRACT=BLOCKED"
}
if ($evidence.signature -ne "Tehkné Solutions" -or $evidence.character_id -ne "training_rival") {
  throw "VM02_C28_EVIDENCE=BLOCKED identity"
}
if ($evidence.status -ne "validated_runtime_active_proxy_fallback_preserved") {
  throw "VM02_C28_EVIDENCE=BLOCKED status=$($evidence.status)"
}
if (-not [bool]$evidence.runtime_policy.runtime_ready -or -not [bool]$evidence.runtime_policy.real_training_rival_active_when_resource_loads) {
  throw "VM02_C28_RUNTIME_READY=BLOCKED"
}
Write-Host "VM02_C28_CONTRACT=PASS source_revision=$($contract.source_revision)"
Write-Host "VM02_C28_RUNTIME_EVIDENCE=PASS product_head=$($evidence.validated_product_head_sha)"

function Resolve-Python {
  foreach ($candidate in @("py", "python", "python3")) {
    try {
      Get-Command $candidate -ErrorAction Stop | Out-Null
      return $candidate
    } catch {}
  }
  throw "VM02_C28_PYTHON=BLOCKED missing"
}

$python = Resolve-Python
Write-Host "VM02_C28_VALIDATOR=BEGIN executable=$python"
if ($python -eq "py") {
  $validatorOutput = @(& py -3 $validatorPath 2>&1)
} else {
  $validatorOutput = @(& $python $validatorPath 2>&1)
}
$validatorExit = $LASTEXITCODE
$validatorOutput | ForEach-Object { Write-Host $_ }
if ($validatorExit -ne 0) { throw "VM02_C28_VALIDATOR=BLOCKED exit=$validatorExit" }

$validatorText = $validatorOutput -join "`n"
foreach ($marker in @(
  "VM02_C28_IMPORTED_PACK=PASS frames=44/44",
  "VM02_C28_IMPORTED_HASHES=PASS frames=44",
  "VM02_C28_PRESENTER_PATH=PASS",
  "VM02_C28_SPRITEFRAMES_STATIC=PASS animations=10 frames=44",
  "VM02_C28_RUNTIME_EVIDENCE=PASS frozen=true",
  "VM02_C28_DISPOSABLE_WRITER=ABSENT",
  "VM02_C28_RUNTIME_READY=PASS presenter_using_real_assets=true fallback_preserved=true"
)) {
  if (-not $validatorText.Contains($marker)) { throw "VM02_C28_VALIDATOR=BLOCKED missing_marker=$marker" }
}
Write-Host "VM02_C28_VALIDATOR=PASS"

$destination = Join-Path $RepoRoot ([string]$contract.destination_root)
$resource = Join-Path $RepoRoot ([string]$contract.sprite_frames_resource)
$manifest = Join-Path $destination "c28-import-manifest.json"
foreach ($path in @($destination, $resource, $manifest)) {
  if (-not (Test-Path $path)) { throw "VM02_C28_PRODUCT=BLOCKED missing=$path" }
}
$frameCount = @(Get-ChildItem (Join-Path $destination "animations") -Filter "char_training_rival__*.png" -File -Recurse).Count
if ($frameCount -ne 44) { throw "VM02_C28_FRAME_COUNT=BLOCKED frames=$frameCount/44" }
Write-Host "VM02_C28_FRAME_COUNT=44/44"
Write-Host "VM02_C28_RIVAL_CANONICAL_READY=PASS"
Write-Host "VM02_C28_REAL_ASSETS_ACTIVE=PASS"
Write-Host "VM02_C28_PROCEDURAL_FALLBACK=PRESERVED"
Write-Host "VM02_C28_V2_RIVAL_INTAKE_GATE=PASS"
Write-Host "SIGNATURE=Tehkné Solutions"

. $reportLib
$branchName = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($branchName)) { $branchName = "detached" }
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C28-V2-RIVAL-INTAKE-BRIDGE" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  CONTRACT="PASS"
  SOURCE_REVISION=[string]$contract.source_revision
  FRAME_COUNT="44/44"
  IMPORTED_HASHES="PASS"
  SPRITEFRAMES="10/10 animations; 44/44 frames"
  GODOT_RUNTIME_BENCH="PASS"
  PRESENTER_REAL_ASSETS="PASS"
  FALLBACK="PRESERVED"
  RUNTIME_READY="PASS"
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard
