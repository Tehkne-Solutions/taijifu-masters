param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_game_feel.gd",
  "scenes/runtime/first_playable_game_feel.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C13_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C13_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C13_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C13_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c13"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "combat-game-feel.stdout.log"
$stderr = Join-Path $logDir "combat-game-feel.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C13_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_game_feel.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(30000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C13_COMBAT_GAME_FEEL_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C13_GAME_FEEL_READY=PASS",
  "VM02_C13_HIT_FLASH=PASS",
  "VM02_C13_HITSTOP_COVERAGE=PASS",
  "VM02_C13_SCREEN_SHAKE_COVERAGE=PASS",
  "VM02_C13_PARTICLE_BURST_COVERAGE=PASS",
  "VM02_C13_IMPACT_EVIDENCE=PASS",
  "VM02_C13_IMPACT_EVIDENCE_COVERAGE=PASS",
  "VM02_C13_ROUND_PRESENTATION=PASS",
  "VM02_C13_C12_COMBAT_CONTRACT=PASS",
  "VM02_C13_RUNTIME=PASS",
  "VM02_C13_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C13_COMBAT_GAME_FEEL_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C13_COMBAT_GAME_FEEL_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c13\first-playable-game-feel-1920x1080.png"
$impactOutput = Join-Path $RepoRoot "artifacts\vm02-c13\impact-game-feel-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C13_COMBAT_GAME_FEEL_GATE=BLOCKED missing_capture" }
if (-not (Test-Path $impactOutput)) { throw "VM02_C13_COMBAT_GAME_FEEL_GATE=BLOCKED missing_impact_capture" }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$impactSha = (Get-FileHash $impactOutput -Algorithm SHA256).Hash.ToLower()
if ($impactSha -eq $sha) { throw "VM02_C13_COMBAT_GAME_FEEL_GATE=BLOCKED impact_capture_matches_final" }
Write-Host "VM02_C13_IMPACT_EVIDENCE_FILE=PASS"
Write-Host "VM02_C13_IMPACT_EVIDENCE_SHA256=$impactSha"
Write-Host "VM02_C13_COMBAT_GAME_FEEL_GATE=PASS"
Write-Host "VM02_C13_COMBAT_GAME_FEEL_GATE_OUTPUT=$output"
Write-Host "VM02_C13_COMBAT_GAME_FEEL_GATE_SHA256=$sha"
Write-Host "VM02_C13_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C13-COMBAT-GAME-FEEL" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  HIT_FLASH="PASS"
  HITSTOP="PASS"
  SCREEN_SHAKE="PASS"
  IMPACT_BURSTS="PASS"
  IMPACT_EVIDENCE="PASS"
  ROUND_PRESENTATION="PASS"
  C12_COMBAT_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  IMPACT_ARTIFACT=$impactOutput
  IMPACT_SHA256=$impactSha
}) -CopyToClipboard
