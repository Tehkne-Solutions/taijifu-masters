param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "tools/generate_lian_wu_riposte6.py",
  "scripts/runtime/first_playable_knockdown_launch_recovery.gd",
  "scenes/runtime/first_playable_knockdown_launch_recovery.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C22_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C22_REQUIRED_FILES=PASS"

$python = Get-Command py -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) { throw "VM02_C22_PYTHON_RESOLVE=BLOCKED" }
Write-Host "VM02_C22_PYTHON_RESOLVE=PASS"
& $python.Source -c "import PIL; print('VM02_C22_PILLOW=PASS'); print('PILLOW_VERSION=' + PIL.__version__)"
if ($LASTEXITCODE -ne 0) { throw "VM02_C22_PILLOW=BLOCKED" }
& $python.Source (Join-Path $RepoRoot "tools\generate_lian_wu_riposte6.py") --repo-root $RepoRoot
if ($LASTEXITCODE -ne 0) { throw "VM02_C22_RIPOSTE6=BLOCKED_GENERATION" }

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C22_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C22_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c22"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "knockdown-launch.stdout.log"
$stderr = Join-Path $logDir "knockdown-launch.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C22_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_knockdown_launch_recovery.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(65000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C22_KNOCKDOWN_LAUNCH_RECOVERY_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C22_KNOCKDOWN_LAUNCH_READY=PASS",
  "VM02_C22_KNOCKDOWN_CONTRACT=PASS",
  "VM02_C22_LAUNCH_CONTRACT=PASS",
  "VM02_C22_RECOVERY_CONTRACT=PASS",
  "VM02_C22_RECOVERY_INVULNERABILITY_CONTRACT=PASS",
  "VM02_C22_REACTION_EVIDENCE_COVERAGE=PASS",
  "VM02_C22_C21_CONTRACT=PASS",
  "VM02_C22_RUNTIME=PASS",
  "VM02_C21_RUNTIME=PASS",
  "VM02_C20_RUNTIME=PASS",
  "VM02_C22_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C22_KNOCKDOWN_LAUNCH_RECOVERY_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C22_KNOCKDOWN_LAUNCH_RECOVERY_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c22\first-playable-knockdown-launch-recovery-1920x1080.png"
$reactionOutput = Join-Path $RepoRoot "artifacts\vm02-c22\knockdown-launch-evidence-1920x1080.png"
foreach ($file in @($output,$reactionOutput)) { if (-not (Test-Path $file)) { throw "VM02_C22_KNOCKDOWN_LAUNCH_RECOVERY_GATE=BLOCKED missing_artifact=$file" } }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$reactionSha = (Get-FileHash $reactionOutput -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C22_EVIDENCE_FILES=PASS"
Write-Host "VM02_C22_KNOCKDOWN_LAUNCH_RECOVERY_GATE=PASS"
Write-Host "VM02_C22_KNOCKDOWN_LAUNCH_RECOVERY_GATE_OUTPUT=$output"
Write-Host "VM02_C22_KNOCKDOWN_LAUNCH_RECOVERY_GATE_SHA256=$sha"
Write-Host "VM02_C22_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C22-KNOCKDOWN-LAUNCH-RECOVERY-FOUNDATION" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  KNOCKDOWN="PASS"
  LAUNCH="PASS"
  RECOVERY="PASS"
  RECOVERY_INVULNERABILITY="PASS"
  REACTION_EVIDENCE="PASS"
  C21_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  REACTION_ARTIFACT=$reactionOutput
  REACTION_SHA256=$reactionSha
}) -CopyToClipboard
