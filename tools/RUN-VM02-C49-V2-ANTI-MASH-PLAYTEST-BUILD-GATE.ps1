param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "export_presets.cfg",
  "config\v2-production-progress.json",
  "scripts\runtime\first_playable_combat_feel_runtime.gd",
  "scripts\combat\technique_data.gd"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C49_MISSING=$_" }
  throw "VM02_C49_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C49_REQUIRED_FILES=PASS"

$progress = Get-Content (Join-Path $RepoRoot "config\v2-production-progress.json") -Raw | ConvertFrom-Json
if ([int]$progress.v2_playable.progress_percent -lt 79) { throw "VM02_C49_C48_PROGRESS=BLOCKED" }
Write-Host "VM02_C49_C48_PROGRESS=PASS"

$feel = Get-Content (Join-Path $RepoRoot "scripts\runtime\first_playable_combat_feel_runtime.gd") -Raw
$timing = Get-Content (Join-Path $RepoRoot "scripts\combat\technique_data.gd") -Raw
if ($feel -notmatch 'REARM_SECONDS := 0\.18' -or $feel -notmatch '_combo\._queue\.clear\(\)') { throw "VM02_C49_ANTI_MASH_BASELINE=BLOCKED" }
$timingContract = (
  $timing -match 'STARTUP_FEEL_SCALE := 1\.28' -and
  $timing -match 'ACTIVE_FEEL_SCALE := 1\.12' -and
  $timing -match 'RECOVERY_FEEL_SCALE := 1\.38' -and
  $timing -match 'startup_frames / 60\.0\) \* STARTUP_FEEL_SCALE' -and
  $timing -match 'active_frames / 60\.0\) \* ACTIVE_FEEL_SCALE' -and
  $timing -match 'recovery_frames / 60\.0\) \* RECOVERY_FEEL_SCALE'
)
if (-not $timingContract) { throw "VM02_C49_ATTACK_TIMING_BASELINE=BLOCKED" }
Write-Host "VM02_C49_ANTI_MASH_BASELINE=PASS"
Write-Host "VM02_C49_ATTACK_TIMING_BASELINE=PASS"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C49_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C49_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$workspace = Split-Path $RepoRoot -Parent
$buildRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c49"
$winDir = Join-Path $buildRoot "windows"
$logDir = Join-Path $buildRoot "logs"
Remove-Item $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $winDir,$logDir | Out-Null
Write-Host "VM02_C49_BUILD_ROOT=$buildRoot"

$winOut = Join-Path $winDir "Taijifu-Masters-V2-C49.exe"
$stdout = Join-Path $logDir "windows-export.stdout.log"
$stderr = Join-Path $logDir "windows-export.stderr.log"
$args = @("--headless","--path",$RepoRoot,"--export-release",'"Windows Desktop"',$winOut)
$proc = Start-Process -FilePath $godot -ArgumentList $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (Test-Path $stdout) { Get-Content $stdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $stderr) { Get-Content $stderr | ForEach-Object { Write-Host $_ } }
if ($proc.ExitCode -ne 0 -or -not (Test-Path $winOut)) { throw "VM02_C49_WINDOWS_EXPORT=BLOCKED exit=$($proc.ExitCode)" }
Write-Host "VM02_C49_WINDOWS_EXPORT=PASS exit=0"

$launcher = Join-Path $buildRoot "START-TAIJIFU-V2-C49-PLAYTEST.cmd"
@(
  '@echo off',
  'cd /d "%~dp0windows"',
  'start "Taijifu Masters C49" "Taijifu-Masters-V2-C49.exe"',
  'exit /b 0'
) | Set-Content $launcher -Encoding ASCII
if (-not (Test-Path $launcher)) { throw "VM02_C49_LAUNCHER=BLOCKED" }
Write-Host "VM02_C49_LAUNCHER=PASS path=$launcher"

$brief = Join-Path $buildRoot "C49-ANTI-MASH-PLAYTEST.md"
@'
# C49 Anti-Mash & Impact Playtest

This build exists to validate the C48 human-feedback correction in the packaged Windows runtime.

Primary test — intentionally play badly:
1. Start on DISCÍPULO.
2. For the first exchange, press only F repeatedly as fast as possible.
3. Confirm repeated F no longer behaves like an automatic combo or dominant strategy.
4. Confirm presses during startup/active/recovery do not preload the next attack.
5. Confirm each strike reads as preparation -> contact -> recovery.
6. Confirm contact has enough pause/weight to perceive the hit.

Secondary test — play deliberately:
7. Use F/G/H with timing rather than mashing.
8. Verify deliberate sequencing is more effective than repeated F.
9. Verify defense, dodge and counter windows are readable between attacks.
10. Verify the fight no longer feels fast/meaningless solely because attacks recycle too quickly.

Human acceptance target:
- F-only mash must NOT be an efficient winning strategy.
- timing and Tai/Ji/Fu choice must outperform mashing.
- hits must feel committed and visibly land.

Do not judge final canonical Training Rival art in this cycle; it remains isolated pending art production.

Tehkné Solutions
'@ | Set-Content $brief -Encoding UTF8
Write-Host "VM02_C49_PLAYTEST_BRIEF=PASS path=$brief"

$sha = (Get-FileHash $winOut -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C49_BUILD_SHA256=$sha"
Write-Host "VM02_C49_ANTI_MASH_PLAYTEST_READY=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C49-V2-ANTI-MASH-PLAYTEST-BUILD",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "C48_BASELINE=PASS",
  "ANTI_MASH_BASELINE=PASS",
  "ATTACK_TIMING_BASELINE=PASS",
  "WINDOWS_EXPORT=PASS",
  "LAUNCHER=PASS",
  "PLAYTEST_READY=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=81%",
  "PROJECT_PROGRESS=58%",
  "BUILD=$winOut",
  "LAUNCHER_PATH=$launcher",
  "BRIEF_PATH=$brief",
  "SHA256=$sha",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C49_V2_ANTI_MASH_PLAYTEST_BUILD_GATE=PASS"
Write-Host "Tehkne Solutions"
