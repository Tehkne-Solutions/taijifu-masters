param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$workspace = Split-Path $RepoRoot -Parent
$assetsRepo = Join-Path $workspace "taijifu-masters-assets"
$source = Join-Path $assetsRepo "production\first_playable\training_rival\source\training_rival_master.png"
$output = Join-Path $assetsRepo "production\first_playable\training_rival\first_playable_lot_01"
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
    $cmd = Get-Command $candidate -ErrorAction Stop
    $python = $candidate
    break
  } catch {}
}
if ($null -eq $python) { throw "VM02_C39_PYTHON=BLOCKED" }
Write-Host "VM02_C39_PYTHON=PASS command=$python"

if (Test-Path $output) {
  foreach ($dir in @("idle", "run")) {
    $path = Join-Path $output $dir
    if (Test-Path $path) { Remove-Item $path -Recurse -Force }
  }
  $manifest = Join-Path $output "manifest.json"
  if (Test-Path $manifest) { Remove-Item $manifest -Force }
}
New-Item -ItemType Directory -Force -Path $output | Out-Null

if ($python -eq "py") {
  & py -3 $generator --source $source --output-root $output
} else {
  & $python $generator --source $source --output-root $output
}
if ($LASTEXITCODE -ne 0) { throw "VM02_C39_P01_MATERIALIZATION=BLOCKED exit=$LASTEXITCODE" }
Write-Host "VM02_C39_P01_MATERIALIZATION=PASS"

$idle = @(Get-ChildItem (Join-Path $output "idle") -Filter "f*.png" -File)
$run = @(Get-ChildItem (Join-Path $output "run") -Filter "f*.png" -File)
if ($idle.Count -ne 6 -or $run.Count -ne 8) {
  throw "VM02_C39_FRAME_CONTRACT=BLOCKED idle=$($idle.Count)/6 run=$($run.Count)/8"
}
Write-Host "VM02_C39_FRAME_CONTRACT=PASS idle=6/6 run=8/8 total=14/14"

Write-Host "VM02_C39_C38_HANDOFF=BEGIN"
& powershell -NoProfile -ExecutionPolicy Bypass -File $c38 -RepoRoot $RepoRoot 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) { throw "VM02_C39_C38_HANDOFF=BLOCKED exit=$LASTEXITCODE" }
Write-Host "VM02_C39_C38_HANDOFF=PASS"
Write-Host "VM02_C39_VISUAL_REVIEW=PENDING"
Write-Host "VM02_C39_RUNTIME_PROMOTION=BLOCKED pending_visual_review"
Write-Host "Tehkne Solutions"
