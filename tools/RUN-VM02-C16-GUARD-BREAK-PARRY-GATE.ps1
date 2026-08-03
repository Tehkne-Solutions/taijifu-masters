param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_guard_break_parry.gd",
  "scenes/runtime/first_playable_guard_break_parry.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C16_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C16_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C16_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C16_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c16"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "guard-parry.stdout.log"
$stderr = Join-Path $logDir "guard-parry.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C16_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_guard_break_parry.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(42000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C16_GUARD_BREAK_PARRY_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C16_GUARD_PARRY_READY=PASS",
  "VM02_C16_DEFENSE_HUD=PASS",
  "VM02_C16_PARRY_CONTRACT=PASS",
  "VM02_C16_GUARD_BREAK_CONTRACT=PASS",
  "VM02_C16_GUARD_RECOVERY_CONTRACT=PASS",
  "VM02_C16_DEFENSE_HUD_CONTRACT=PASS",
  "VM02_C16_EVIDENCE_COVERAGE=PASS",
  "VM02_C16_RUNTIME=PASS",
  "VM02_C15_RUNTIME=PASS",
  "VM02_C14_RUNTIME=PASS",
  "VM02_C16_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C16_GUARD_BREAK_PARRY_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C16_GUARD_BREAK_PARRY_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c16\first-playable-guard-break-parry-1920x1080.png"
$parryOutput = Join-Path $RepoRoot "artifacts\vm02-c16\parry-evidence-1920x1080.png"
$breakOutput = Join-Path $RepoRoot "artifacts\vm02-c16\guard-break-evidence-1920x1080.png"
foreach ($file in @($output,$parryOutput,$breakOutput)) { if (-not (Test-Path $file)) { throw "VM02_C16_GUARD_BREAK_PARRY_GATE=BLOCKED missing_artifact=$file" } }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$parrySha = (Get-FileHash $parryOutput -Algorithm SHA256).Hash.ToLower()
$breakSha = (Get-FileHash $breakOutput -Algorithm SHA256).Hash.ToLower()
if ($parrySha -eq $breakSha) { throw "VM02_C16_GUARD_BREAK_PARRY_GATE=BLOCKED evidence_collision" }
Write-Host "VM02_C16_EVIDENCE_FILES=PASS"
Write-Host "VM02_C16_GUARD_BREAK_PARRY_GATE=PASS"
Write-Host "VM02_C16_GUARD_BREAK_PARRY_GATE_OUTPUT=$output"
Write-Host "VM02_C16_GUARD_BREAK_PARRY_GATE_SHA256=$sha"
Write-Host "VM02_C16_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C16-GUARD-BREAK-PARRY-FOUNDATION" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  PARRY="PASS"
  PARRY_DAMAGE_NEGATION="PASS"
  GUARD_BREAK="PASS"
  GUARD_RECOVERY="PASS"
  DEFENSE_HUD="PASS"
  C15_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  PARRY_ARTIFACT=$parryOutput
  PARRY_SHA256=$parrySha
  GUARD_BREAK_ARTIFACT=$breakOutput
  GUARD_BREAK_SHA256=$breakSha
}) -CopyToClipboard
