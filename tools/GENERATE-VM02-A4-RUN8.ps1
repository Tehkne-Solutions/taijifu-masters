param(
  [Parameter(Mandatory=$false)][string]$RepoRoot = "."
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
  param([string]$Command,[string[]]$Arguments)
  $previous = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = & $Command @Arguments 2>&1
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
  return [pscustomobject]@{ ExitCode=$code; Output=@($output) }
}

$python = Resolve-Python
if (-not $python) { Write-Host "VM02_A4_RUN8=BLOCKED_PYTHON_NOT_FOUND"; exit 2 }
Write-Host "VM02_A4_PYTHON_RESOLVE=PASS"
Write-Host "PYTHON=$python"

$probe = Invoke-NativeProbe -Command $python -Arguments @("-c", "import PIL; print(PIL.__version__)")
if ($probe.ExitCode -ne 0) {
  Write-Host "VM02_A4_PILLOW=MISSING"
  $install = Invoke-NativeProbe -Command $python -Arguments @("-m", "pip", "install", "Pillow")
  foreach ($line in $install.Output) { if ($null -ne $line) { Write-Host "$line" } }
  if ($install.ExitCode -ne 0) { Write-Host "VM02_A4_RUN8=BLOCKED_PILLOW_INSTALL"; exit 3 }
  $probe = Invoke-NativeProbe -Command $python -Arguments @("-c", "import PIL; print(PIL.__version__)")
  if ($probe.ExitCode -ne 0) { Write-Host "VM02_A4_RUN8=BLOCKED_PILLOW_IMPORT_AFTER_INSTALL"; exit 3 }
}
Write-Host "VM02_A4_PILLOW=PASS"
$version = ($probe.Output | Select-Object -Last 1)
if ($version) { Write-Host "PILLOW_VERSION=$version" }

$generator = Join-Path $RepoRoot "tools\generate_lian_wu_run8.py"
if (-not (Test-Path $generator)) { Write-Host "VM02_A4_RUN8=BLOCKED_GENERATOR_MISSING"; exit 4 }
& $python $generator --repo-root $RepoRoot
if ($LASTEXITCODE -ne 0) { Write-Host "VM02_A4_RUN8=BLOCKED_GENERATION"; exit $LASTEXITCODE }

$validator = Join-Path $RepoRoot "tools\validate_lian_wu_locomotion_core.py"
if (Test-Path $validator) {
  $previous = $ErrorActionPreference
  try { $ErrorActionPreference = "Continue"; & $python $validator; $validatorExit = $LASTEXITCODE }
  finally { $ErrorActionPreference = $previous }
  Write-Host "VM02_A4_LOCOMOTION_VALIDATOR_EXIT=$validatorExit"
}
Write-Host "VM02_A4_RUN8=READY_FOR_GODOT_REVIEW"
