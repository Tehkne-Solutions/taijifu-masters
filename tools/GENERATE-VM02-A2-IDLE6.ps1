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

function Invoke-NativeProbe {
  param(
    [Parameter(Mandatory=$true)][string]$Command,
    [Parameter(Mandatory=$true)][string[]]$Arguments
  )
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = & $Command @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = @($output)
  }
}

$python = Resolve-Python
if (-not $python) {
  Write-Host "VM02_A2_IDLE6=BLOCKED_PYTHON_NOT_FOUND"
  exit 2
}

Write-Host "VM02_A2_PYTHON_RESOLVE=PASS"
Write-Host "PYTHON=$python"

$pillowProbe = Invoke-NativeProbe -Command $python -Arguments @("-c", "import PIL; print(PIL.__version__)")
if ($pillowProbe.ExitCode -ne 0) {
  Write-Host "VM02_A2_PILLOW=MISSING"
  Write-Host "Installing Pillow in the current Python environment..."

  $pipInstall = Invoke-NativeProbe -Command $python -Arguments @("-m", "pip", "install", "Pillow")
  foreach ($line in $pipInstall.Output) {
    if ($null -ne $line -and "$line".Trim().Length -gt 0) { Write-Host "$line" }
  }
  if ($pipInstall.ExitCode -ne 0) {
    Write-Host "VM02_A2_IDLE6=BLOCKED_PILLOW_INSTALL"
    exit 3
  }

  $pillowProbe = Invoke-NativeProbe -Command $python -Arguments @("-c", "import PIL; print(PIL.__version__)")
  if ($pillowProbe.ExitCode -ne 0) {
    Write-Host "VM02_A2_IDLE6=BLOCKED_PILLOW_IMPORT_AFTER_INSTALL"
    foreach ($line in $pillowProbe.Output) {
      if ($null -ne $line -and "$line".Trim().Length -gt 0) { Write-Host "$line" }
    }
    exit 3
  }
}

$pillowVersion = ($pillowProbe.Output | Select-Object -Last 1)
Write-Host "VM02_A2_PILLOW=PASS"
if ($pillowVersion) { Write-Host "PILLOW_VERSION=$pillowVersion" }

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
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $python $validator
    $validatorExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }
  # Full locomotion is expected to remain blocked while walk/run/jump/fall/land are absent.
  Write-Host "VM02_A2_LOCOMOTION_VALIDATOR_EXIT=$validatorExit"
}

Write-Host "VM02_A2_IDLE6=READY_FOR_GODOT_REVIEW"
