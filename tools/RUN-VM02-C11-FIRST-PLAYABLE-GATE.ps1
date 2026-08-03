param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_level.gd",
  "scenes/runtime/first_playable_level.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C11_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C11_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C11_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C11_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c11"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "first-playable.stdout.log"
$stderr = Join-Path $logDir "first-playable.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C11_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_level.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(25000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C11_FIRST_PLAYABLE_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C11_STAGE_READY=PASS",
  "VM02_C11_SPAWNS_READY=PASS",
  "VM02_C11_CAMERA_READY=PASS",
  "VM02_C11_HUD_READY=PASS",
  "VM02_C11_ROUND_START=PASS",
  "VM02_C11_PLAYER_DAMAGED=PASS",
  "VM02_C11_AI_ACTIVE=PASS",
  "VM02_C11_PLAYER_COMBAT=PASS",
  "VM02_C11_WIN_CONDITION=PASS",
  "VM02_C11_RUNTIME=PASS",
  "VM02_C11_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C11_FIRST_PLAYABLE_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C11_FIRST_PLAYABLE_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c11\first-playable-level-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C11_FIRST_PLAYABLE_GATE=BLOCKED missing_capture" }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C11_FIRST_PLAYABLE_GATE=PASS"
Write-Host "VM02_C11_FIRST_PLAYABLE_GATE_OUTPUT=$output"
Write-Host "VM02_C11_FIRST_PLAYABLE_GATE_SHA256=$sha"
Write-Host "VM02_C11_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C11-FIRST-PLAYABLE" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  STAGE="PASS"
  SPAWNS="PASS"
  CAMERA="PASS"
  HUD="PASS"
  ROUND_START="PASS"
  PLAYER_DAMAGED="PASS"
  AI_ACTIVE="PASS"
  PLAYER_COMBAT="PASS"
  WIN_CONDITION="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
}) -CopyToClipboard
