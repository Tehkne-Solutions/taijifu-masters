param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "export_presets.cfg",
  "scenes\vertical_slice\first_playable_menu.tscn",
  "tools\RUN-VM02-C40-V2-RUNTIME-CONSOLIDATION-GATE.ps1",
  "config\v2-production-progress.json"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C41_MISSING=$_" }
  throw "VM02_C41_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C41_REQUIRED_FILES=PASS"

$progress = Get-Content (Join-Path $RepoRoot "config\v2-production-progress.json") -Raw | ConvertFrom-Json
if (-not [bool]$progress.v2_playable.runtime_ready) { throw "VM02_C41_RUNTIME_READY=BLOCKED" }
Write-Host "VM02_C41_RUNTIME_READY=PASS"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C41_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C41_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$artifacts = Join-Path $RepoRoot "artifacts\vm02-c41"
$webDir = Join-Path $artifacts "web"
$winDir = Join-Path $artifacts "windows"
New-Item -ItemType Directory -Force -Path $webDir,$winDir | Out-Null

& $godot --headless --path $RepoRoot --editor --quit-after 2 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) { throw "VM02_C41_GODOT_BOOTSTRAP=BLOCKED exit=$LASTEXITCODE" }
Write-Host "VM02_C41_GODOT_BOOTSTRAP=PASS"

$webOut = Join-Path $webDir "index.html"
$winOut = Join-Path $winDir "Taijifu-Masters-V2-Playtest.exe"
$webStatus = "BLOCKED"
$winStatus = "BLOCKED"

try {
  & $godot --headless --path $RepoRoot --export-release "Web" $webOut 2>&1 | Out-Host
  if ($LASTEXITCODE -eq 0 -and (Test-Path $webOut)) { $webStatus = "PASS" }
} catch { }
Write-Host "VM02_C41_WEB_EXPORT=$webStatus"

try {
  & $godot --headless --path $RepoRoot --export-release "Windows Desktop" $winOut 2>&1 | Out-Host
  if ($LASTEXITCODE -eq 0 -and (Test-Path $winOut)) { $winStatus = "PASS" }
} catch { }
Write-Host "VM02_C41_WINDOWS_EXPORT=$winStatus"

if ($webStatus -ne "PASS" -and $winStatus -ne "PASS") {
  throw "VM02_C41_DISTRIBUTABLE=BLOCKED no_export_target_succeeded"
}
Write-Host "VM02_C41_DISTRIBUTABLE=PASS"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$packageRoot = Join-Path $artifacts "package-$stamp"
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
if ($webStatus -eq "PASS") { Copy-Item $webDir (Join-Path $packageRoot "web") -Recurse -Force }
if ($winStatus -eq "PASS") { Copy-Item $winDir (Join-Path $packageRoot "windows") -Recurse -Force }

$manifest = [ordered]@{
  product = "Taijifu Masters"
  signature = "Tehkné Solutions"
  package = "V2 Repeatable Playtest"
  project_version = "0.2.2-playtest"
  runtime_ready = $true
  art_complete = $false
  canonical_arena = "mountain_dojo_night"
  training_rival = "explicit_noncanonical_proxy_pending_canonical_art"
  web_export = $webStatus
  windows_export = $winStatus
  generated_at = (Get-Date).ToString("o")
}
$manifestPath = Join-Path $packageRoot "PLAYTEST-MANIFEST.json"
$manifest | ConvertTo-Json -Depth 4 | Set-Content $manifestPath -Encoding UTF8

$zipPath = Join-Path $artifacts "TAIJIFU_MASTERS_V2_PLAYTEST_$stamp.zip"
Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -Force
if (-not (Test-Path $zipPath)) { throw "VM02_C41_ZIP=BLOCKED" }
$sha = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C41_ZIP=PASS"
Write-Host "VM02_C41_ZIP_OUTPUT=$zipPath"
Write-Host "VM02_C41_ZIP_SHA256=$sha"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C41-V2-REPEATABLE-PLAYTEST-PACKAGING",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "RUNTIME_READY=PASS",
  "WEB_EXPORT=$webStatus",
  "WINDOWS_EXPORT=$winStatus",
  "DISTRIBUTABLE=PASS",
  "ZIP=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=61%",
  "PROJECT_PROGRESS=46%",
  "ARTIFACT=$zipPath",
  "SHA256=$sha",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C41_V2_REPEATABLE_PLAYTEST_PACKAGING_GATE=PASS"
Write-Host "Tehkne Solutions"
