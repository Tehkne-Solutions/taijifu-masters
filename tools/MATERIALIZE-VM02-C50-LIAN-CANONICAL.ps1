param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

function Resolve-Python {
  foreach ($name in @("py", "python", "python3")) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }
  return $null
}

$python = Resolve-Python
if (-not $python) { throw "VM02_C50_LIAN_PYTHON=BLOCKED" }
Write-Host "VM02_C50_LIAN_PYTHON=PASS"
Write-Host "PYTHON=$python"

& $python -c "import PIL; print('VM02_C50_LIAN_PILLOW=PASS')"
if ($LASTEXITCODE -ne 0) { throw "VM02_C50_LIAN_PILLOW=BLOCKED" }

$generators = @(
  "tools\generate_lian_wu_idle6.py",
  "tools\generate_lian_wu_run8.py",
  "tools\generate_lian_wu_jump_start4.py",
  "tools\generate_lian_wu_jump_loop3.py",
  "tools\generate_lian_wu_fall3.py",
  "tools\generate_lian_wu_land4.py",
  "tools\generate_lian_wu_body_hook6.py"
)

foreach ($rel in $generators) {
  $path = Join-Path $RepoRoot $rel
  if (-not (Test-Path $path)) {
    Write-Host "VM02_C50_LIAN_GENERATOR=BLOCKED missing=$rel"
    throw "VM02_C50_LIAN_GENERATORS=BLOCKED"
  }
  Write-Host "VM02_C50_LIAN_GENERATOR=BEGIN file=$rel"
  & $python $path --repo-root $RepoRoot
  if ($LASTEXITCODE -ne 0) {
    throw "VM02_C50_LIAN_GENERATOR=BLOCKED file=$rel exit=$LASTEXITCODE"
  }
  Write-Host "VM02_C50_LIAN_GENERATOR=PASS file=$rel"
}

$materializer = Join-Path $RepoRoot "tools\materialize_c50_lian_spriteframes.py"
& $python $materializer --repo-root $RepoRoot
if ($LASTEXITCODE -ne 0) { throw "VM02_C50_LIAN_SPRITEFRAMES=BLOCKED" }

$tres = Join-Path $RepoRoot "assets\tgap\pack_01_lian_wu\first_playable_lot_01\lian_wu_first_playable_frames.tres"
$manifest = Join-Path $RepoRoot "assets\tgap\pack_01_lian_wu\first_playable_lot_01\materialization-manifest.json"
if (-not (Test-Path $tres) -or -not (Test-Path $manifest)) {
  throw "VM02_C50_LIAN_OUTPUT=BLOCKED"
}

Write-Host "VM02_C50_LIAN_OUTPUT=PASS"
Write-Host "VM02_C50_LIAN_TRES=$tres"
Write-Host "VM02_C50_LIAN_MANIFEST=$manifest"
Write-Host "VM02_C50_LIAN_CANONICAL_READY=PASS"
Write-Host "VM02_C50_LIAN_ANIMATION_COVERAGE=PARTIAL_REAL_ONLY"
Write-Host "VM02_C50_LIAN_PROCEDURAL=RETIRED"
Write-Host "Tehkne Solutions"
