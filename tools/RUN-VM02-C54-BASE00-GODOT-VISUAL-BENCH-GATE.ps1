param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$scene = "scenes/runtime/base00_godot_visual_bench.tscn"
$script = "scripts/runtime/base00_godot_visual_bench.gd"
$asset = "assets/modular_fighters/base_00/base_fighter_v1_master.png"
$manifest = "assets/modular_fighters/base_00/manifest.json"
$qa = "assets/modular_fighters/base_00/qa/base_fighter_v1_master.qa.json"
$assembler = "scripts/characters/modular_fighter_assembler.gd"
$profile = "scripts/characters/modular_fighter_profile.gd"
$c52 = "tools/RUN-VM02-C52-BASE00-ART-MASTER-INTEGRATION-GATE.ps1"
$reportLib = "tools/lib/Write-TehkneGateReport.ps1"
$progressPath = "config/v2-production-progress.json"

foreach ($required in @($scene,$script,$asset,$manifest,$qa,$assembler,$profile,$c52,$reportLib,$progressPath)) {
  if (-not (Test-Path (Join-Path $RepoRoot $required))) {
    throw "VM02_C54_REQUIRED_FILES=BLOCKED missing=$required"
  }
}
Write-Host "VM02_C54_REQUIRED_FILES=PASS"

Write-Host "VM02_C54_C52_PREFLIGHT=BEGIN"
$c52Output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot $c52) -RepoRoot $RepoRoot 2>&1
if ($LASTEXITCODE -ne 0) {
  $c52Output | ForEach-Object { Write-Host $_ }
  throw "VM02_C54_C52_PREFLIGHT=BLOCKED exit=$LASTEXITCODE"
}
$c52Text = $c52Output -join "`n"
foreach ($marker in @(
  "VM02_C52_SHA256=PASS",
  "VM02_C52_RGBA_TRANSPARENCY=PASS",
  "VM02_C52_QA=PASS",
  "VM02_C52_PIVOT_BASELINE=PASS",
  "VM02_C52_FOUNDATION_HANDOFF=PASS"
)) {
  if ($c52Text -notmatch [regex]::Escape($marker)) {
    throw "VM02_C54_C52_PREFLIGHT=BLOCKED missing_marker=$marker"
  }
}
$c52Output | Where-Object { $_ -match '^VM02_C52_(SHA256|CANVAS|RGBA_TRANSPARENCY|QA|MANIFEST|PIVOT_BASELINE|FOUNDATION_HANDOFF)=' } | ForEach-Object { Write-Host $_ }
Write-Host "VM02_C54_C52_PREFLIGHT=PASS"

$benchScript = Get-Content (Join-Path $RepoRoot $script) -Raw
$benchContract = [ordered]@{
  ASSEMBLER_PRELOAD = 'preload("res://scripts/characters/modular_fighter_assembler.gd")'
  PROFILE_PRELOAD = 'preload("res://scripts/characters/modular_fighter_profile.gd")'
  IMAGE_RUNTIME_LOAD = 'Image.load_from_file(ProjectSettings.globalize_path(BASE_ASSET_PATH))'
  IMAGE_TEXTURE_RUNTIME = 'ImageTexture.create_from_image(image)'
  ALPHA_BOUNDS = '_alpha_used_rect(image)'
  PROFILE_CONFIGURE = 'assembler.call("configure", profile)'
  BODY_SLOT_ATTACH = 'assembler.call("attach_visual_module", &"body_base", sprite)'
  TARGET_HEIGHT = 'const TARGET_VISUAL_HEIGHT := 132.0'
  BASELINE = 'const BENCH_BASELINE_Y := 790.0'
  HORIZONTAL_FLIP = 'sprite.flip_h = flipped'
}
foreach ($entry in $benchContract.GetEnumerator()) {
  if (-not $benchScript.Contains([string]$entry.Value)) {
    throw "VM02_C54_BENCH_CONTRACT=BLOCKED missing=$($entry.Key)"
  }
  Write-Host "VM02_C54_BENCH_CONTRACT_$($entry.Key)=PASS"
}
if ($benchScript.Contains('preload("res://assets/modular_fighters/base_00/base_fighter_v1_master.png")')) {
  throw "VM02_C54_PNG_PRELOAD=BLOCKED"
}
Write-Host "VM02_C54_PNG_PRELOAD=RETIRED"
if ($benchScript -match 'draw_circle\(' -or $benchScript -match 'draw_colored_polygon\(') {
  throw "VM02_C54_PROCEDURAL_FIGHTER_RENDERER=BLOCKED"
}
Write-Host "VM02_C54_BENCH_CONTRACT=PASS"
Write-Host "VM02_C54_PROCEDURAL_FIGHTER_RENDERER=RETIRED"

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$godotCommand = Get-Command godot -ErrorAction SilentlyContinue
if ($godotCommand) { $godotCandidates += $godotCommand.Source }
$godot4Command = Get-Command godot4 -ErrorAction SilentlyContinue
if ($godot4Command) { $godotCandidates += $godot4Command.Source }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -ExpandProperty FullName)
}
$godotExe = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godotExe) { throw "VM02_C54_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C54_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c54"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir "base00-godot-visual-bench.stdout.log"
$stderr = Join-Path $logDir "base00-godot-visual-bench.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue

$args = @("--path",$RepoRoot,"--resolution","1920x1080","--quit-after","900","res://$scene")
$process = Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (-not $process.WaitForExit(30000)) {
  try { $process.Kill() } catch {}
  Get-Content $stdout -ErrorAction SilentlyContinue
  Get-Content $stderr -ErrorAction SilentlyContinue
  throw "VM02_C54_GATE=BLOCKED timeout"
}

Get-Content $stdout -ErrorAction SilentlyContinue
Get-Content $stderr -ErrorAction SilentlyContinue
$text = (Get-Content $stdout -Raw -ErrorAction SilentlyContinue) + (Get-Content $stderr -Raw -ErrorAction SilentlyContinue)

foreach ($fatal in @(
  "SCRIPT ERROR",
  "Parse Error",
  "Compile Error",
  "Failed to load script",
  "VM02_C54_BASE00_IMAGE=BLOCKED",
  "VM02_C54_BASE00_TEXTURE=BLOCKED",
  "VM02_C54_CANVAS=BLOCKED",
  "VM02_C54_ALPHA_BOUNDS=BLOCKED",
  "VM02_C54_MODULAR_ASSEMBLY=BLOCKED",
  "VM02_C54_BODY_SLOT=BLOCKED",
  "VM02_C54_GAMEPLAY_HEIGHT=BLOCKED",
  "VM02_C54_BASELINE=BLOCKED",
  "VM02_C54_CAPTURE=BLOCKED"
)) {
  if ($text -match [regex]::Escape($fatal)) {
    throw "VM02_C54_GATE=BLOCKED fatal=$fatal"
  }
}

$markers = @(
  "VM02_C54_BASE00_TEXTURE=PASS",
  "VM02_C54_CANVAS=PASS size=1024x1024",
  "VM02_C54_GAMEPLAY_HEIGHT=PASS actual=132.000",
  "VM02_C54_BASELINE=PASS y=790.0",
  "VM02_C54_FLIP=PASS",
  "VM02_C54_MODULAR_ASSEMBLY=PASS slot=body_base",
  "VM02_C54_HITBOX_SCALE=PASS visual_height=132",
  "VM02_C54_PROCEDURAL_FIGHTER_RENDERER=RETIRED",
  "VM02_C54_CAPTURE=PASS",
  "VM02_C54_RUNTIME=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) {
    throw "VM02_C54_GATE=BLOCKED missing_marker=$marker"
  }
}

$output = Join-Path $RepoRoot "artifacts\vm02-c54\base00-godot-bench-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C54_GATE=BLOCKED missing_capture" }

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::FromFile($output)
try {
  if ($bitmap.Width -ne 1920 -or $bitmap.Height -ne 1080) {
    throw "VM02_C54_CAPTURE_DIMENSIONS=BLOCKED size=$($bitmap.Width)x$($bitmap.Height)"
  }
} finally {
  $bitmap.Dispose()
}
Write-Host "VM02_C54_CAPTURE_DIMENSIONS=PASS size=1920x1080"

$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C54_GODOT_VISUAL_BENCH_GATE=PASS"
Write-Host "VM02_C54_VISUAL_PROOF_OUTPUT=$output"
Write-Host "VM02_C54_VISUAL_PROOF_SHA256=$sha"
Write-Host "VM02_C54_REVIEW=PENDING_VISUAL_REVIEW"
Write-Host "VM02_C54_NEXT_ACTION=review_capture_before_base01"

. (Join-Path $RepoRoot $reportLib)
$progress = Get-Content (Join-Path $RepoRoot $progressPath) -Raw | ConvertFrom-Json
$branchName = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C54-BASE00-GODOT-VISUAL-BENCH" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  C52_PREFLIGHT="PASS"
  BASE00_TEXTURE="PASS"
  CANVAS="1024x1024"
  GAMEPLAY_HEIGHT="132px"
  PIVOT_BASELINE="PASS"
  FLIP="PASS"
  MODULAR_ASSEMBLY="PASS"
  PROCEDURAL_FIGHTER_RENDERER="RETIRED"
  CAPTURE="PASS"
  HUMAN_REVIEW="PENDING"
  ARTIFACT=$output
  SHA256=$sha
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard

Write-Host "Tehkne Solutions"
