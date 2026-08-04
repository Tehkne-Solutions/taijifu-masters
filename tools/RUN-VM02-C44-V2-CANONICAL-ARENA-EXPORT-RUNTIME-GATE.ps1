param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "export_presets.cfg",
  "scripts\vertical_slice\first_playable_menu.gd",
  "scripts\vertical_slice\first_playable_environment_art.gd",
  "scripts\vertical_slice\canonical_arena_parallax.gd",
  "assets\pack_03_stages\mountain_dojo_night\background.png",
  "assets\pack_03_stages\mountain_dojo_night\midground.png",
  "assets\pack_03_stages\mountain_dojo_night\foreground.png"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C44_MISSING=$_" }
  throw "VM02_C44_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C44_REQUIRED_FILES=PASS"

$menuSource = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\first_playable_menu.gd") -Raw
$envSource = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\first_playable_environment_art.gd") -Raw
$parallaxSource = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\canonical_arena_parallax.gd") -Raw
if ($menuSource -notmatch 'C44_RUNTIME_PROOF_ARG') { throw "VM02_C44_RUNTIME_PROOF_ROUTE=BLOCKED" }
if ($envSource -notmatch 'ResourceLoader\.exists\(path, "Texture2D"\)') { throw "VM02_C44_EXPORT_SAFE_SELECTION=BLOCKED" }
if ($parallaxSource -notmatch 'ResourceLoader\.load\(path, "Texture2D"\)') { throw "VM02_C44_EXPORT_SAFE_TEXTURE_LOAD=BLOCKED" }
if ($parallaxSource -match 'image\.load\(absolute_path\)') { throw "VM02_C44_RAW_IMAGE_LOAD_RETIRED=BLOCKED" }
Write-Host "VM02_C44_RUNTIME_PROOF_ROUTE=PASS"
Write-Host "VM02_C44_EXPORT_SAFE_SELECTION=PASS"
Write-Host "VM02_C44_EXPORT_SAFE_TEXTURE_LOAD=PASS"
Write-Host "VM02_C44_RAW_IMAGE_LOAD_RETIRED=PASS"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C44_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C44_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$workspace = Split-Path $RepoRoot -Parent
$buildRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c44"
$winDir = Join-Path $buildRoot "windows"
$logDir = Join-Path $buildRoot "logs"
Remove-Item $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $winDir,$logDir | Out-Null

$winOut = Join-Path $winDir "Taijifu-Masters-V2-C44.exe"
$exportStdout = Join-Path $logDir "windows-export.stdout.log"
$exportStderr = Join-Path $logDir "windows-export.stderr.log"
$exportArgs = @("--headless","--path",$RepoRoot,"--export-release",'"Windows Desktop"',$winOut)
$exportProc = Start-Process -FilePath $godot -ArgumentList $exportArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $exportStdout -RedirectStandardError $exportStderr
if (Test-Path $exportStdout) { Get-Content $exportStdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $exportStderr) { Get-Content $exportStderr | ForEach-Object { Write-Host $_ } }
if ($exportProc.ExitCode -ne 0 -or -not (Test-Path $winOut)) { throw "VM02_C44_WINDOWS_EXPORT=BLOCKED exit=$($exportProc.ExitCode)" }
Write-Host "VM02_C44_WINDOWS_EXPORT=PASS exit=0"

$runtimeStdout = Join-Path $logDir "runtime.stdout.log"
$runtimeStderr = Join-Path $logDir "runtime.stderr.log"
# Important: exported games boot into first_playable_menu.tscn. The proof argument
# deliberately enters the combat scene before the arena assertions are evaluated.
$runtimeArgs = @("--headless","--quit-after","8","--","--v2-c44-runtime-proof")
$runtimeProc = Start-Process -FilePath $winOut -ArgumentList $runtimeArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $runtimeStdout -RedirectStandardError $runtimeStderr
$runtimeText = ""
if (Test-Path $runtimeStdout) { $runtimeText += (Get-Content $runtimeStdout -Raw); Get-Content $runtimeStdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $runtimeStderr) { $runtimeText += "`n" + (Get-Content $runtimeStderr -Raw); Get-Content $runtimeStderr | ForEach-Object { Write-Host $_ } }
if ($runtimeProc.ExitCode -ne 0) { throw "VM02_C44_EXPORTED_RUNTIME_BOOT=BLOCKED exit=$($runtimeProc.ExitCode)" }
Write-Host "VM02_C44_EXPORTED_RUNTIME_BOOT=PASS exit=0"

if ($runtimeText -notmatch 'V2_C44_RUNTIME_PROOF=ENTER_COMBAT') { throw "VM02_C44_RUNTIME_PROOF_ENTRY=BLOCKED" }
Write-Host "VM02_C44_RUNTIME_PROOF_ENTRY=PASS"
if ($runtimeText -notmatch 'V2_CANONICAL_ARENA_SELECTION=PASS') { throw "VM02_C44_CANONICAL_SELECTION_IN_EXPORT=BLOCKED" }
if ($runtimeText -notmatch 'V2_CANONICAL_ARENA_RUNTIME=PASS layers=3') { throw "VM02_C44_CANONICAL_LAYERS_IN_EXPORT=BLOCKED" }
if ($runtimeText -match 'V2_CANONICAL_ARENA_SELECTION=BLOCKED') { throw "VM02_C44_PROCEDURAL_FALLBACK_RETIRED=BLOCKED" }
Write-Host "VM02_C44_CANONICAL_SELECTION_IN_EXPORT=PASS"
Write-Host "VM02_C44_CANONICAL_LAYERS_IN_EXPORT=PASS layers=3/3"
Write-Host "VM02_C44_PROCEDURAL_FALLBACK_RETIRED=PASS"
Write-Host "VM02_C44_VISUAL_RUNTIME_RECOVERY=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C44-V2-CANONICAL-ARENA-EXPORT-RUNTIME",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "RUNTIME_PROOF_ENTRY=PASS",
  "EXPORT_SAFE_SELECTION=PASS",
  "EXPORT_SAFE_TEXTURE_LOAD=PASS",
  "WINDOWS_EXPORT=PASS",
  "EXPORTED_RUNTIME_BOOT=PASS",
  "CANONICAL_SELECTION_IN_EXPORT=PASS",
  "CANONICAL_LAYERS=3/3",
  "PROCEDURAL_FALLBACK_RETIRED=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=68%",
  "PROJECT_PROGRESS=50%",
  "BUILD=$winOut",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C44_V2_CANONICAL_ARENA_EXPORT_RUNTIME_GATE=PASS"
Write-Host "Tehkne Solutions"
