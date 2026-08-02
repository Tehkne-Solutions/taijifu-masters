param(
  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

function Resolve-Python {
  foreach ($cmdName in @("py", "python", "python3")) {
    $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmdName }
  }
  return $null
}

$python = Resolve-Python
if (-not $python) {
  Write-Host "VM02_A2_IDLE6=BLOCKED_PYTHON_NOT_FOUND"
  exit 2
}

Write-Host "VM02_A2_PYTHON_RESOLVE=PASS"
Write-Host "PYTHON=$python"

& $python -c "import PIL" 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "VM02_A2_PILLOW=MISSING"
  Write-Host "Installing Pillow in the current Python environment..."
  & $python -m pip install Pillow
  if ($LASTEXITCODE -ne 0) {
    Write-Host "VM02_A2_IDLE6=BLOCKED_PILLOW_INSTALL"
    exit 3
  }
}

Write-Host "VM02_A2_PILLOW=PASS"

$generator = Join-Path $RepoRoot "tools\generate_lian_wu_idle6.py"
if (-not (Test-Path $generator)) {
  Write-Host "VM02_A2_IDLE6=BLOCKED_GENERATOR_MISSING"
  exit 4
}

& $python $generator --repo-root $RepoRoot
if ($LASTEXITCODE -ne 0) {
  Write-Host "VM02_A2_IDLE6=BLOCKED_GENERATION"
  exit $LASTEXITCODE
}

$validator = Join-Path $RepoRoot "tools\validate_lian_wu_locomotion_core.py"
if (Test-Path $validator) {
  & $python $validator --repo-root $RepoRoot
  $validatorExit = $LASTEXITCODE
  # Full locomotion is expected to remain blocked while walk/run/jump/fall/land are absent.
  Write-Host "VM02_A2_LOCOMOTION_VALIDATOR_EXIT=$validatorExit"
}

Write-Host "VM02_A2_IDLE6=READY_FOR_GODOT_REVIEW"
