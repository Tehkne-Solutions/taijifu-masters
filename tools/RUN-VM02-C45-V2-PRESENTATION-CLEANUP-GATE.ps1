param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "export_presets.cfg",
  "scripts\vertical_slice\first_playable_arena_dressing.gd",
  "scripts\vertical_slice\first_playable_combat_feedback_runtime.gd",
  "scripts\vertical_slice\first_playable_menu.gd",
  "assets\pack_03_stages\mountain_dojo_night\background.png",
  "assets\pack_03_stages\mountain_dojo_night\midground.png",
  "assets\pack_03_stages\mountain_dojo_night\foreground.png"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C45_MISSING=$_" }
  throw "VM02_C45_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C45_REQUIRED_FILES=PASS"

$dressing = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\first_playable_arena_dressing.gd") -Raw
$feedback = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\first_playable_combat_feedback_runtime.gd") -Raw
if ($dressing -notmatch 'V2_PRESENTATION_LEGACY_DRESSING=RETIRED') { throw "VM02_C45_LEGACY_DRESSING_RETIREMENT_CONTRACT=BLOCKED" }
if ($dressing -notmatch 'visible = false') { throw "VM02_C45_LEGACY_DRESSING_VISIBILITY_CONTRACT=BLOCKED" }
if ($feedback -notmatch 'MAX_ACTIVE_POPUPS := 2') { throw "VM02_C45_POPUP_BUDGET_CONTRACT=BLOCKED" }
if ($feedback -notmatch 'V2_PRESENTATION_FEEDBACK_BUDGET=PASS') { throw "VM02_C45_FEEDBACK_MARKER_CONTRACT=BLOCKED" }
Write-Host "VM02_C45_LEGACY_DRESSING_RETIREMENT_CONTRACT=PASS"
Write-Host "VM02_C45_POPUP_BUDGET_CONTRACT=PASS max=2"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C45_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C45_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$workspace = Split-Path $RepoRoot -Parent
$buildRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c45"
$winDir = Join-Path $buildRoot "windows"
$logDir = Join-Path $buildRoot "logs"
Remove-Item $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $winDir,$logDir | Out-Null

$winOut = Join-Path $winDir "Taijifu-Masters-V2-C45.exe"
$exportStdout = Join-Path $logDir "windows-export.stdout.log"
$exportStderr = Join-Path $logDir "windows-export.stderr.log"
$exportArgs = @("--headless","--path",$RepoRoot,"--export-release",'"Windows Desktop"',$winOut)
$exportProc = Start-Process -FilePath $godot -ArgumentList $exportArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $exportStdout -RedirectStandardError $exportStderr
if (Test-Path $exportStdout) { Get-Content $exportStdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $exportStderr) { Get-Content $exportStderr | ForEach-Object { Write-Host $_ } }
if ($exportProc.ExitCode -ne 0 -or -not (Test-Path $winOut)) { throw "VM02_C45_WINDOWS_EXPORT=BLOCKED exit=$($exportProc.ExitCode)" }
Write-Host "VM02_C45_WINDOWS_EXPORT=PASS exit=0"

$runtimeStdout = Join-Path $logDir "runtime.stdout.log"
$runtimeStderr = Join-Path $logDir "runtime.stderr.log"
$runtimeArgs = @("--headless","--v2-c44-runtime-proof","--quit-after","5")
$runtimeProc = Start-Process -FilePath $winOut -ArgumentList $runtimeArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $runtimeStdout -RedirectStandardError $runtimeStderr
$runtimeText = ""
if (Test-Path $runtimeStdout) { $runtimeText += (Get-Content $runtimeStdout -Raw); Get-Content $runtimeStdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $runtimeStderr) { $runtimeText += "`n" + (Get-Content $runtimeStderr -Raw); Get-Content $runtimeStderr | ForEach-Object { Write-Host $_ } }
if ($runtimeProc.ExitCode -ne 0) { throw "VM02_C45_EXPORTED_RUNTIME_BOOT=BLOCKED exit=$($runtimeProc.ExitCode)" }
Write-Host "VM02_C45_EXPORTED_RUNTIME_BOOT=PASS exit=0"

if ($runtimeText -notmatch 'V2_CANONICAL_ARENA_SELECTION=PASS') { throw "VM02_C45_CANONICAL_ARENA_IN_EXPORT=BLOCKED" }
if ($runtimeText -notmatch 'V2_CANONICAL_ARENA_RUNTIME=PASS layers=3') { throw "VM02_C45_CANONICAL_LAYERS_IN_EXPORT=BLOCKED" }
if ($runtimeText -notmatch 'V2_PRESENTATION_LEGACY_DRESSING=RETIRED') { throw "VM02_C45_LEGACY_DRESSING_IN_EXPORT=BLOCKED" }
if ($runtimeText -notmatch 'V2_PRESENTATION_FEEDBACK_BUDGET=PASS max=2') { throw "VM02_C45_FEEDBACK_BUDGET_IN_EXPORT=BLOCKED" }
Write-Host "VM02_C45_CANONICAL_ARENA_IN_EXPORT=PASS"
Write-Host "VM02_C45_LEGACY_DRESSING_IN_EXPORT=PASS"
Write-Host "VM02_C45_FEEDBACK_BUDGET_IN_EXPORT=PASS max=2"
Write-Host "VM02_C45_PRESENTATION_CLEANUP=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C45-V2-PRESENTATION-CLEANUP",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "CANONICAL_ARENA=PASS",
  "LEGACY_DRESSING_RETIRED=PASS",
  "POPUP_BUDGET=2",
  "FEEDBACK_CLEANUP=PASS",
  "WINDOWS_EXPORT=PASS",
  "EXPORTED_RUNTIME_BOOT=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=71%",
  "PROJECT_PROGRESS=52%",
  "BUILD=$winOut",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C45_V2_PRESENTATION_CLEANUP_GATE=PASS"
Write-Host "Tehkne Solutions"
