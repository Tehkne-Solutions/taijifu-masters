param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "export_presets.cfg",
  "config\v2-production-progress.json",
  "scripts\vertical_slice\first_playable_camera_composition.gd",
  "scripts\ai\bot_behavior_catalog.gd"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C47_MISSING=$_" }
  throw "VM02_C47_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C47_REQUIRED_FILES=PASS"

$progress = Get-Content (Join-Path $RepoRoot "config\v2-production-progress.json") -Raw | ConvertFrom-Json
if ([int]$progress.v2_playable.progress_percent -lt 74) { throw "VM02_C47_C46_PROGRESS=BLOCKED" }
Write-Host "VM02_C47_C46_PROGRESS=PASS"

$camera = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\first_playable_camera_composition.gd") -Raw
$bots = Get-Content (Join-Path $RepoRoot "scripts\ai\bot_behavior_catalog.gd") -Raw
if ($camera -notmatch 'MIN_ZOOM := 0\.68' -or $camera -notmatch 'MAX_ZOOM := 1\.06') { throw "VM02_C47_CAMERA_BASELINE=BLOCKED" }
if ($bots -notmatch '"defense_chance": 0\.62' -or $bots -notmatch '"mistake_chance": 0\.09') { throw "VM02_C47_DISCIPLE_BASELINE=BLOCKED" }
Write-Host "VM02_C47_CAMERA_BASELINE=PASS"
Write-Host "VM02_C47_DISCIPLE_BASELINE=PASS"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C47_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C47_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$workspace = Split-Path $RepoRoot -Parent
$buildRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c47"
$winDir = Join-Path $buildRoot "windows"
$logDir = Join-Path $buildRoot "logs"
Remove-Item $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $winDir,$logDir | Out-Null
Write-Host "VM02_C47_BUILD_ROOT=$buildRoot"

$winOut = Join-Path $winDir "Taijifu-Masters-V2-C47.exe"
$stdout = Join-Path $logDir "windows-export.stdout.log"
$stderr = Join-Path $logDir "windows-export.stderr.log"
$args = @("--headless","--path",$RepoRoot,"--export-release",'"Windows Desktop"',$winOut)
$proc = Start-Process -FilePath $godot -ArgumentList $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (Test-Path $stdout) { Get-Content $stdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $stderr) { Get-Content $stderr | ForEach-Object { Write-Host $_ } }
if ($proc.ExitCode -ne 0 -or -not (Test-Path $winOut)) { throw "VM02_C47_WINDOWS_EXPORT=BLOCKED exit=$($proc.ExitCode)" }
Write-Host "VM02_C47_WINDOWS_EXPORT=PASS exit=0"

$launcher = Join-Path $buildRoot "START-TAIJIFU-V2-C47-PLAYTEST.cmd"
$launcherLines = @(
  '@echo off',
  'cd /d "%~dp0windows"',
  'start "Taijifu Masters C47" "Taijifu-Masters-V2-C47.exe"',
  'exit /b 0'
)
$launcherLines | Set-Content $launcher -Encoding ASCII
if (-not (Test-Path $launcher)) { throw "VM02_C47_LAUNCHER=BLOCKED" }
Write-Host "VM02_C47_LAUNCHER=PASS path=$launcher"

$brief = Join-Path $buildRoot "C47-COMPARATIVE-PLAYTEST.md"
@'
# C47 Comparative Playtest

Compare this build against the C45 baseline.

Baseline telemetry:
- difficulty: DISCÍPULO
- result: player KO win
- duration: 39.297 s
- player confirmed hits: 12
- CPU confirmed hits: 4
- player max combo: 6
- CPU max combo: 0
- balance feedback: too_easy

Review:
1. Are fighters visibly larger during close exchanges?
2. Does camera vertical motion feel calmer?
3. Is impact shake less noisy?
4. Does DISCÍPULO defend/react more often?
5. Does CPU land more than 4 confirmed hits?
6. Does CPU produce at least one meaningful multi-hit sequence?
7. Is fight duration closer to 50–75 seconds without feeling passive?
8. Does the arena remain readable and dominant?
9. Is feedback readable with max two transient popups?

Do not judge canonical Training Rival art in this cycle; it remains an isolated dependency.

Tehkné Solutions
'@ | Set-Content $brief -Encoding UTF8
Write-Host "VM02_C47_PLAYTEST_BRIEF=PASS path=$brief"

$sha = (Get-FileHash $winOut -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C47_BUILD_SHA256=$sha"
Write-Host "VM02_C47_COMPARATIVE_PLAYTEST_READY=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C47-V2-COMPARATIVE-PLAYTEST-BUILD",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "C46_BASELINE=PASS",
  "WINDOWS_EXPORT=PASS",
  "LAUNCHER=PASS",
  "COMPARATIVE_PLAYTEST_READY=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=76%",
  "PROJECT_PROGRESS=55%",
  "BUILD=$winOut",
  "LAUNCHER_PATH=$launcher",
  "BRIEF_PATH=$brief",
  "SHA256=$sha",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C47_V2_COMPARATIVE_PLAYTEST_BUILD_GATE=PASS"
Write-Host "Tehkne Solutions"
