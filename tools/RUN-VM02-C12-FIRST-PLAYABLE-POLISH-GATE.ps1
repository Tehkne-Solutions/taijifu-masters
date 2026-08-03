param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_polish.gd",
  "scenes/runtime/first_playable_polish.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C12_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C12_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C12_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C12_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c12"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "first-playable-polish.stdout.log"
$stderr = Join-Path $logDir "first-playable-polish.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C12_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_polish.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(25000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C12_FIRST_PLAYABLE_POLISH_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C12_FIGHTER_SCALE=PASS",
  "VM02_C12_GROUND_ALIGNMENT=PASS",
  "VM02_C12_STAGE_COMPOSITION=PASS",
  "VM02_C12_HUD_POLISH=PASS",
  "VM02_C12_CAMERA_POLISH=PASS",
  "VM02_C12_PRESENTATION_READY=PASS",
  "VM02_C12_C11_COMBAT_CONTRACT=PASS",
  "VM02_C12_WIN_CONDITION=PASS",
  "VM02_C12_RUNTIME=PASS",
  "VM02_C12_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C12_FIRST_PLAYABLE_POLISH_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C12_FIRST_PLAYABLE_POLISH_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c12\first-playable-polish-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C12_FIRST_PLAYABLE_POLISH_GATE=BLOCKED missing_capture" }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C12_FIRST_PLAYABLE_POLISH_GATE=PASS"
Write-Host "VM02_C12_FIRST_PLAYABLE_POLISH_GATE_OUTPUT=$output"
Write-Host "VM02_C12_FIRST_PLAYABLE_POLISH_GATE_SHA256=$sha"
Write-Host "VM02_C12_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C12-FIRST-PLAYABLE-POLISH" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  FIGHTER_SCALE="PASS"
  GROUND_ALIGNMENT="PASS"
  STAGE_COMPOSITION="PASS"
  HUD_POLISH="PASS"
  CAMERA_POLISH="PASS"
  C11_COMBAT_CONTRACT="PASS"
  WIN_CONDITION="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
}) -CopyToClipboard
