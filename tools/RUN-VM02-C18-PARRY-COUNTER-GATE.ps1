param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_parry_counter_cancel.gd",
  "scenes/runtime/first_playable_parry_counter_cancel.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C18_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C18_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C18_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C18_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c18"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "parry-counter.stdout.log"
$stderr = Join-Path $logDir "parry-counter.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C18_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_parry_counter_cancel.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(46000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C18_PARRY_COUNTER_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C18_PARRY_COUNTER_READY=PASS",
  "VM02_C18_COUNTER_WINDOW_CONTRACT=PASS",
  "VM02_C18_CANCEL_WINDOW_CONTRACT=PASS",
  "VM02_C18_COUNTER_CONSUME_CONTRACT=PASS",
  "VM02_C18_COUNTER_EVIDENCE_COVERAGE=PASS",
  "VM02_C18_C17_CONTRACT=PASS",
  "VM02_C18_RUNTIME=PASS",
  "VM02_C17_RUNTIME=PASS",
  "VM02_C16_RUNTIME=PASS",
  "VM02_C18_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C18_PARRY_COUNTER_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C18_PARRY_COUNTER_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c18\first-playable-parry-counter-1920x1080.png"
$counterOutput = Join-Path $RepoRoot "artifacts\vm02-c18\parry-counter-evidence-1920x1080.png"
foreach ($file in @($output,$counterOutput)) { if (-not (Test-Path $file)) { throw "VM02_C18_PARRY_COUNTER_GATE=BLOCKED missing_artifact=$file" } }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$counterSha = (Get-FileHash $counterOutput -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C18_EVIDENCE_FILES=PASS"
Write-Host "VM02_C18_PARRY_COUNTER_GATE=PASS"
Write-Host "VM02_C18_PARRY_COUNTER_GATE_OUTPUT=$output"
Write-Host "VM02_C18_PARRY_COUNTER_GATE_SHA256=$sha"
Write-Host "VM02_C18_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C18-PARRY-COUNTER-CANCEL-FOUNDATION" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  COUNTER_WINDOW="PASS"
  CANCEL_WINDOW="PASS"
  COUNTER_CONSUME="PASS"
  COUNTER_EVIDENCE="PASS"
  C17_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  COUNTER_ARTIFACT=$counterOutput
  COUNTER_SHA256=$counterSha
}) -CopyToClipboard