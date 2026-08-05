param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "scripts\runtime\first_playable_combat_feel_runtime.gd",
  "scripts\combat\technique_data.gd",
  "scripts\vertical_slice\first_playable_combo_runtime.gd",
  "config\v2-production-progress.json"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C48_MISSING=$_" }
  throw "VM02_C48_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C48_REQUIRED_FILES=PASS"

$project = Get-Content (Join-Path $RepoRoot "project.godot") -Raw
if ($project -notmatch 'FirstPlayableCombatFeelRuntime="\*res://scripts/runtime/first_playable_combat_feel_runtime.gd"') {
  throw "VM02_C48_COMBAT_FEEL_AUTOLOAD=BLOCKED"
}
Write-Host "VM02_C48_COMBAT_FEEL_AUTOLOAD=PASS"

$feel = Get-Content (Join-Path $RepoRoot "scripts\runtime\first_playable_combat_feel_runtime.gd") -Raw
$feelChecks = @(
  'const REARM_SECONDS := 0.18',
  '_combo._queue.clear()',
  'COMPLETE O GOLPE',
  'requires_attack_completion',
  'buffer_during_attack'
)
foreach ($needle in $feelChecks) {
  if ($feel -notlike "*$needle*") { throw "VM02_C48_ANTI_MASH_CONTRACT=BLOCKED missing=$needle" }
}
Write-Host "VM02_C48_ANTI_MASH_CONTRACT=PASS"

$technique = Get-Content (Join-Path $RepoRoot "scripts\combat\technique_data.gd") -Raw
if ($technique -notmatch 'STARTUP_FEEL_SCALE := 1\.28' -or
    $technique -notmatch 'ACTIVE_FEEL_SCALE := 1\.12' -or
    $technique -notmatch 'RECOVERY_FEEL_SCALE := 1\.38') {
  throw "VM02_C48_ATTACK_TIMING_CONTRACT=BLOCKED"
}
Write-Host "VM02_C48_ATTACK_TIMING_CONTRACT=PASS"

$progress = Get-Content (Join-Path $RepoRoot "config\v2-production-progress.json") -Raw | ConvertFrom-Json
if ([int]$progress.v2_playable.progress_percent -lt 76) { throw "VM02_C48_PROGRESS_BASELINE=BLOCKED" }
if ($progress.evidence.c47_human_review.dominant_input -ne "repeated_F") { throw "VM02_C48_PLAYTEST_EVIDENCE=BLOCKED" }
Write-Host "VM02_C48_PLAYTEST_EVIDENCE=PASS"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C48_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C48_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$logDir = Join-Path $RepoRoot "artifacts\vm02-c48\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdoutLog = Join-Path $logDir "godot-bootstrap.stdout.log"
$stderrLog = Join-Path $logDir "godot-bootstrap.stderr.log"
Remove-Item $stdoutLog,$stderrLog -Force -ErrorAction SilentlyContinue

$proc = Start-Process `
  -FilePath $godot `
  -ArgumentList @("--headless","--path",('"' + $RepoRoot + '"'),"--editor","--quit-after","2") `
  -RedirectStandardOutput $stdoutLog `
  -RedirectStandardError $stderrLog `
  -Wait `
  -PassThru `
  -NoNewWindow

if (Test-Path $stdoutLog) {
  Get-Content $stdoutLog | ForEach-Object { Write-Host $_ }
}
if (Test-Path $stderrLog) {
  $stderrLines = @(Get-Content $stderrLog)
  foreach ($line in $stderrLines) {
    if ($line -match 'SCRIPT ERROR|Parse Error|Compile Error|ERROR:') {
      Write-Host $line
    } elseif ($line -match 'WARNING:') {
      Write-Host "VM02_C48_GODOT_WARNING=$line"
    } elseif ($line.Trim()) {
      Write-Host $line
    }
  }
}

if ($proc.ExitCode -ne 0) { throw "VM02_C48_GODOT_BOOTSTRAP=BLOCKED exit=$($proc.ExitCode)" }
$fatalPattern = 'SCRIPT ERROR|Parse Error|Compile Error|ERROR:'
if ((Test-Path $stderrLog) -and ((Get-Content $stderrLog -Raw) -match $fatalPattern)) {
  throw "VM02_C48_GODOT_BOOTSTRAP=BLOCKED fatal_script_or_engine_error"
}
Write-Host "VM02_C48_GODOT_BOOTSTRAP=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C48-V2-ATTACK-CADENCE-IMPACT",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "ANTI_MASH=PASS",
  "ATTACK_COMMITMENT=PASS",
  "TIMING_SCALE=PASS",
  "PLAYTEST_EVIDENCE=PASS",
  "GODOT_BOOTSTRAP=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=79%",
  "PROJECT_PROGRESS=57%",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C48_V2_ATTACK_CADENCE_IMPACT_GATE=PASS"
Write-Host "Tehkne Solutions"
