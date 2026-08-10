param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$workspace = Split-Path $RepoRoot -Parent
$assetsRepo = Join-Path $workspace "taijifu-masters-assets"
$source = Join-Path $assetsRepo "production\first_playable\training_rival\source\training_rival_master.png"
$output = Join-Path $assetsRepo "production\first_playable\training_rival\first_playable_lot_01"
$staging = Join-Path $output "__p01_staging"
$animations = Join-Path $output "animations"
$generator = Join-Path $RepoRoot "tools\materialize_training_rival_p01.py"
$c38 = Join-Path $RepoRoot "tools\RUN-VM02-C38-TRAINING-RIVAL-P01-INTAKE-GATE.ps1"

if (-not (Test-Path $generator)) { throw "VM02_C39_REQUIRED_FILES=BLOCKED missing_generator" }
if (-not (Test-Path $c38)) { throw "VM02_C39_REQUIRED_FILES=BLOCKED missing_c38" }
if (-not (Test-Path (Join-Path $assetsRepo ".git"))) { throw "VM02_C39_ASSETS_REPO=BLOCKED missing_assets_repo" }
Write-Host "VM02_C39_REQUIRED_FILES=PASS"

if (-not (Test-Path $source)) {
  Write-Host "VM02_C39_CANONICAL_MASTER=BLOCKED"
  Write-Host "VM02_C39_MASTER_EXPECTED=$source"
  Write-Host "VM02_C39_POLICY=NO_CONTACT_SHEET_SOURCE"
  Write-Host "VM02_C39_POLICY=NO_BACKGROUND_REMOVAL"
  Write-Host "VM02_C39_POLICY=NO_LIAN_SOURCE_REUSE"
  Write-Host "VM02_C39_P01_MATERIALIZATION=BLOCKED waiting_for_clean_canonical_master"
  exit 3
}
Write-Host "VM02_C39_CANONICAL_MASTER=PASS path=$source"

$python = $null
foreach ($candidate in @("py", "python", "python3")) {
  try {
    Get-Command $candidate -ErrorAction Stop | Out-Null
    $python = $candidate
    break
  } catch {}
}
if ($null -eq $python) { throw "VM02_C39_PYTHON=BLOCKED" }
Write-Host "VM02_C39_PYTHON=PASS command=$python"

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

if ($python -eq "py") {
  & py -3 $generator --source $source --output-root $staging
} else {
  & $python $generator --source $source --output-root $staging
}
if ($LASTEXITCODE -ne 0) { throw "VM02_C39_P01_MATERIALIZATION=BLOCKED exit=$LASTEXITCODE" }

foreach ($mode in @("idle", "run")) {
  $dest = Join-Path $animations $mode
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $src = Join-Path $staging $mode
  if (-not (Test-Path $src)) { throw "VM02_C39_P01_MATERIALIZATION=BLOCKED missing_staging_$mode" }
  Get-ChildItem $src -Filter "char_training_rival__${mode}__f*.png" -File | ForEach-Object {
    Move-Item $_.FullName (Join-Path $dest $_.Name) -Force
  }
}

$generatedManifest = Join-Path $staging "manifest.json"
if (-not (Test-Path $generatedManifest)) { throw "VM02_C39_P01_MANIFEST=BLOCKED missing_generated_manifest" }
Move-Item $generatedManifest (Join-Path $output "p01-manifest.json") -Force
Remove-Item $staging -Recurse -Force
Write-Host "VM02_C39_P01_MATERIALIZATION=PASS"

$idle = @(Get-ChildItem (Join-Path $animations "idle") -Filter "char_training_rival__idle__f*.png" -File)
$run = @(Get-ChildItem (Join-Path $animations "run") -Filter "char_training_rival__run__f*.png" -File)
if ($idle.Count -ne 6 -or $run.Count -ne 8) {
  throw "VM02_C39_FRAME_CONTRACT=BLOCKED idle=$($idle.Count)/6 run=$($run.Count)/8"
}
Write-Host "VM02_C39_FRAME_CONTRACT=PASS idle=6/6 run=8/8 total=14/14"
Write-Host "VM02_C39_CANONICAL_LAYOUT=PASS animations/<animation>/char_training_rival__<animation>__fNNN.png"

Write-Host "VM02_C39_C38_HANDOFF=BEGIN"
& powershell -NoProfile -ExecutionPolicy Bypass -File $c38 -RepoRoot $RepoRoot 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) { throw "VM02_C39_C38_HANDOFF=BLOCKED exit=$LASTEXITCODE" }
Write-Host "VM02_C39_C38_HANDOFF=PASS"
Write-Host "VM02_C39_VISUAL_REVIEW=PENDING"
Write-Host "VM02_C39_RUNTIME_PROMOTION=BLOCKED until_44_of_44_and_runtime_review"
Write-Host "Tehkne Solutions"
