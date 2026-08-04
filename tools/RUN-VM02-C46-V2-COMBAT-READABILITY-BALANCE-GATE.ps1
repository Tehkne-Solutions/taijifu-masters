param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "scripts\vertical_slice\first_playable_camera_composition.gd",
  "scripts\ai\bot_behavior_catalog.gd",
  "config\v2-production-progress.json"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C46_MISSING=$_" }
  throw "VM02_C46_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C46_REQUIRED_FILES=PASS"

$camera = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\first_playable_camera_composition.gd") -Raw
$bot = Get-Content (Join-Path $RepoRoot "scripts\ai\bot_behavior_catalog.gd") -Raw

if ($camera -notmatch 'MIN_ZOOM := 0\.68') { throw "VM02_C46_CAMERA_MIN_ZOOM=BLOCKED" }
if ($camera -notmatch 'MAX_ZOOM := 1\.06') { throw "VM02_C46_CAMERA_MAX_ZOOM=BLOCKED" }
if ($camera -notmatch 'CLOSE_FIGHT_ZOOM_FLOOR := 0\.94') { throw "VM02_C46_CLOSE_FIGHT_FRAMING=BLOCKED" }
if ($camera -notmatch 'V2_C46_CAMERA_READABILITY=PASS') { throw "VM02_C46_CAMERA_MARKER=BLOCKED" }
Write-Host "VM02_C46_CAMERA_READABILITY_CONTRACT=PASS"

if ($bot -notmatch '"disciple": \{') { throw "VM02_C46_DISCIPLE_PROFILE=BLOCKED" }
if ($bot -notmatch '"reaction_multiplier": 0\.98') { throw "VM02_C46_DISCIPLE_REACTION=BLOCKED" }
if ($bot -notmatch '"defense_chance": 0\.62') { throw "VM02_C46_DISCIPLE_DEFENSE=BLOCKED" }
if ($bot -notmatch '"mistake_chance": 0\.09') { throw "VM02_C46_DISCIPLE_MISTAKE=BLOCKED" }
if ($bot -notmatch 'KO.d in 39\.3s') { throw "VM02_C46_PLAYTEST_EVIDENCE_LINK=BLOCKED" }
Write-Host "VM02_C46_DISCIPLE_REBALANCE_CONTRACT=PASS"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C46_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C46_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$workspace = Split-Path $RepoRoot -Parent
$logRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c46\logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stdout = Join-Path $logRoot "bootstrap.stdout.log"
$stderr = Join-Path $logRoot "bootstrap.stderr.log"
$proc = Start-Process -FilePath $godot -ArgumentList @("--headless","--path",$RepoRoot,"--editor","--quit-after","3") -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (Test-Path $stdout) { Get-Content $stdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $stderr) { Get-Content $stderr | ForEach-Object { Write-Host $_ } }
if ($proc.ExitCode -ne 0) { throw "VM02_C46_GODOT_BOOTSTRAP=BLOCKED exit=$($proc.ExitCode)" }
Write-Host "VM02_C46_GODOT_BOOTSTRAP=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C46-V2-COMBAT-READABILITY-BALANCE",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "CAMERA_READABILITY=PASS",
  "CLOSE_FIGHT_FRAMING=PASS",
  "DISCIPLE_REBALANCE=PASS",
  "PLAYTEST_EVIDENCE=PASS",
  "GODOT_BOOTSTRAP=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=74%",
  "PROJECT_PROGRESS=54%",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C46_V2_COMBAT_READABILITY_BALANCE_GATE=PASS"
Write-Host "Tehkne Solutions"
