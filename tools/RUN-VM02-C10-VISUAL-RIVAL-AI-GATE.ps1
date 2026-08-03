param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/opponent_ai_foundation.gd",
  "scripts/runtime/opponent_visual_sparring_rival.gd",
  "scripts/runtime/opponent_visual_ai_integration_gate.gd",
  "scenes/runtime/opponent_visual_ai_integration_gate.tscn"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C10_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C10_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C10_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C10_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c10"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "visual-rival-ai.stdout.log"
$stderr = Join-Path $logDir "visual-rival-ai.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C10_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/opponent_visual_ai_integration_gate.tscn","--","--capture-and-quit") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(18000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C10_VISUAL_RIVAL_AI_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C10_VISUAL_BOUND_TO_AI=PASS",
  "VM02_C10_GEOMETRIC_PLACEHOLDER=OFF",
  "VM02_C10_VISUAL_STATE_COVERAGE=PASS",
  "VM02_C10_AI_COMBAT_CONTRACT=PASS",
  "VM02_C10_RUNTIME=PASS",
  "VM02_C10_CAPTURE=PASS"
)
foreach ($marker in $markers) { if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C10_VISUAL_RIVAL_AI_GATE=BLOCKED missing_marker=$marker" } }
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C10_VISUAL_RIVAL_AI_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c10\visual-rival-ai-integration-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C10_VISUAL_RIVAL_AI_GATE=BLOCKED missing_capture" }
Write-Host "VM02_C10_VISUAL_RIVAL_AI_GATE=PASS"
Write-Host "VM02_C10_VISUAL_RIVAL_AI_GATE_OUTPUT=$output"
Write-Host "VM02_C10_VISUAL_RIVAL_AI_GATE_SHA256=$((Get-FileHash $output -Algorithm SHA256).Hash.ToLower())"
Write-Host "VM02_C10_REVIEW=PENDING_VISUAL_REVIEW"
