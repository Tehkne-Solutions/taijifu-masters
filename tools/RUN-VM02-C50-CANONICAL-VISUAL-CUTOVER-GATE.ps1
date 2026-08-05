param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "export_presets.cfg",
  "docs\TAIJIFU-MODULAR-FIGHTER-SYSTEM.md",
  "config\modular-fighter-standard-v1.json",
  "config\fighter-presets\preset_lian_wu.json",
  "config\fighter-presets\preset_training_rival.json",
  "scripts\characters\modular_fighter_profile.gd",
  "scripts\vertical_slice\first_playable_character_identity.gd",
  "scripts\vertical_slice\first_playable_lot01_presenter.gd",
  "scripts\vertical_slice\training_rival_lot01_presenter.gd",
  "scripts\vertical_slice\first_playable_arena_dressing.gd",
  "tools\MATERIALIZE-VM02-C50-LIAN-CANONICAL.ps1",
  "tools\materialize_c50_lian_spriteframes.py",
  "assets\pack_03_stages\mountain_dojo_night\background.png",
  "assets\pack_03_stages\mountain_dojo_night\midground.png",
  "assets\pack_03_stages\mountain_dojo_night\foreground.png"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C50_MISSING_REQUIRED=$_" }
  throw "VM02_C50_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C50_REQUIRED_FILES=PASS"

$standardPath = Join-Path $RepoRoot "config\modular-fighter-standard-v1.json"
$standard = Get-Content $standardPath -Raw | ConvertFrom-Json
if ($standard.status -ne "approved_project_standard") { throw "VM02_C50_MODULAR_STANDARD=BLOCKED status" }
if ($standard.visual_target.style -ne "chibi_manga_comic") { throw "VM02_C50_MODULAR_STANDARD=BLOCKED style" }
if ($standard.authoring.procedural_fighter_fallback_allowed_in_production -ne $false) { throw "VM02_C50_MODULAR_STANDARD=BLOCKED procedural_policy" }
$requiredSlots = @("body_base","skin","face","eyes","brows","hair_back","hair_front","torso_inner","torso_outer","arms","hands","waist","legs","feet","weapon_main")
foreach ($slot in $requiredSlots) {
  if ($standard.slots -notcontains $slot) { throw "VM02_C50_MODULAR_STANDARD=BLOCKED missing_slot=$slot" }
}
Write-Host "VM02_C50_MODULAR_FIGHTER_STANDARD=PASS"
Write-Host "VM02_C50_VISUAL_STYLE_STANDARD=PASS style=chibi_manga_comic"
Write-Host "VM02_C50_PRODUCTION_PROXY_POLICY=PASS disabled"

foreach ($presetFile in @("preset_lian_wu.json","preset_training_rival.json")) {
  $presetPath = Join-Path $RepoRoot "config\fighter-presets\$presetFile"
  $preset = Get-Content $presetPath -Raw | ConvertFrom-Json
  if (-not $preset.profile_id -or $preset.base_body_id -ne "base_fighter_v1") {
    throw "VM02_C50_PRESET_CONTRACT=BLOCKED preset=$presetFile"
  }
  foreach ($module in $preset.modules.PSObject.Properties.Name) {
    if ($standard.slots -notcontains $module) {
      throw "VM02_C50_PRESET_CONTRACT=BLOCKED preset=$presetFile unknown_slot=$module"
    }
  }
}
Write-Host "VM02_C50_PRESET_CONTRACT=PASS count=2/2"

$profileScript = Get-Content (Join-Path $RepoRoot "scripts\characters\modular_fighter_profile.gd") -Raw
if ($profileScript -notmatch 'class_name ModularFighterProfile' -or $profileScript -notmatch 'validate_against_standard') {
  throw "VM02_C50_MODULAR_PROFILE_RUNTIME=BLOCKED"
}
Write-Host "VM02_C50_MODULAR_PROFILE_RUNTIME=PASS"

$identityPath = Join-Path $RepoRoot "scripts\vertical_slice\first_playable_character_identity.gd"
$identity = Get-Content $identityPath -Raw
if ($identity -match 'func _draw\(' -or $identity -match 'draw_circle\(' -or $identity -match 'draw_colored_polygon\(') {
  throw "VM02_C50_PROCEDURAL_CHARACTER_RENDERER=BLOCKED"
}
if ($identity -notmatch '"procedural_character_renderer": false' -or $identity -notmatch '"canonical_visual_cutover_required": true') {
  throw "VM02_C50_CHARACTER_CUTOVER_CONTRACT=BLOCKED"
}
Write-Host "VM02_C50_PROCEDURAL_CHARACTER_RENDERER=RETIRED"
Write-Host "VM02_C50_CHARACTER_CUTOVER_CONTRACT=PASS"

$dressing = Get-Content (Join-Path $RepoRoot "scripts\vertical_slice\first_playable_arena_dressing.gd") -Raw
if ($dressing -notmatch 'V2_PRESENTATION_LEGACY_DRESSING=RETIRED' -or $dressing -notmatch 'visible = false') {
  throw "VM02_C50_ARENA_PROCEDURAL_RETIREMENT=BLOCKED"
}
Write-Host "VM02_C50_CANONICAL_ARENA_FILES=PASS count=3/3"
Write-Host "VM02_C50_ARENA_PROCEDURAL_RETIREMENT=PASS"

$lianFrames = Join-Path $RepoRoot "assets\tgap\pack_01_lian_wu\first_playable_lot_01\lian_wu_first_playable_frames.tres"
$rivalFrames = Join-Path $RepoRoot "assets\tgap\training_rival\first_playable_lot_01\training_rival_first_playable_frames.tres"

if (-not (Test-Path $lianFrames)) {
  Write-Host "VM02_C50_LIAN_AUTO_MATERIALIZE=BEGIN"
  & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "tools\MATERIALIZE-VM02-C50-LIAN-CANONICAL.ps1") -RepoRoot $RepoRoot
  if ($LASTEXITCODE -ne 0) {
    throw "VM02_C50_LIAN_AUTO_MATERIALIZE=BLOCKED exit=$LASTEXITCODE"
  }
  Write-Host "VM02_C50_LIAN_AUTO_MATERIALIZE=PASS"
} else {
  Write-Host "VM02_C50_LIAN_AUTO_MATERIALIZE=SKIP_ALREADY_PRESENT"
}

$lianReady = Test-Path $lianFrames
$rivalReady = Test-Path $rivalFrames
Write-Host ("VM02_C50_LIAN_CANONICAL_FRAMES=" + $(if ($lianReady) { "PASS" } else { "BLOCKED" }))
Write-Host ("VM02_C50_RIVAL_CANONICAL_FRAMES=" + $(if ($rivalReady) { "PASS" } else { "BLOCKED" }))

if (-not $lianReady -or -not $rivalReady) {
  Write-Host "VM02_C50_VISUAL_CUTOVER_READY=BLOCKED"
  Write-Host "VM02_C50_REASON=canonical_character_spriteframes_missing"
  Write-Host "VM02_C50_EXPECTED_LIAN=$lianFrames"
  Write-Host "VM02_C50_EXPECTED_RIVAL=$rivalFrames"
  Write-Host "VM02_C50_NO_PROGRESS_PROMOTION=PASS"
  if ($lianReady -and -not $rivalReady) {
    Write-Host "VM02_C50_NEXT_BLOCKER=TRAINING_RIVAL_CANONICAL_ART"
  }
  throw "VM02_C50_CANONICAL_CHARACTER_ART=BLOCKED"
}

$godotCandidates = @()
if ($env:GODOT_EXE) { $godotCandidates += $env:GODOT_EXE }
if ($env:GODOT_CLI_EXE) { $godotCandidates += $env:GODOT_CLI_EXE }
$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
if (Test-Path $wingetRoot) {
  $godotCandidates += @(Get-ChildItem $wingetRoot -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw "VM02_C50_GODOT_RESOLVE=BLOCKED" }
Write-Host "VM02_C50_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$workspace = Split-Path $RepoRoot -Parent
$buildRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c50"
$winDir = Join-Path $buildRoot "windows"
$logDir = Join-Path $buildRoot "logs"
Remove-Item $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $winDir,$logDir | Out-Null

$winOut = Join-Path $winDir "Taijifu-Masters-V2-C50.exe"
$stdout = Join-Path $logDir "windows-export.stdout.log"
$stderr = Join-Path $logDir "windows-export.stderr.log"
$args = @("--headless","--path",$RepoRoot,"--export-release",'"Windows Desktop"',$winOut)
$proc = Start-Process -FilePath $godot -ArgumentList $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (Test-Path $stdout) { Get-Content $stdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $stderr) { Get-Content $stderr | ForEach-Object { Write-Host $_ } }
if ($proc.ExitCode -ne 0 -or -not (Test-Path $winOut)) { throw "VM02_C50_WINDOWS_EXPORT=BLOCKED exit=$($proc.ExitCode)" }
Write-Host "VM02_C50_WINDOWS_EXPORT=PASS exit=0"

$sha = (Get-FileHash $winOut -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C50_BUILD_SHA256=$sha"
Write-Host "VM02_C50_CANONICAL_VISUAL_CUTOVER=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C50-CANONICAL-VISUAL-CUTOVER",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "MODULAR_FIGHTER_STANDARD=PASS",
  "VISUAL_STYLE_STANDARD=chibi_manga_comic",
  "PRESET_CONTRACT=PASS",
  "PROCEDURAL_CHARACTER_RENDERER=RETIRED",
  "CANONICAL_ARENA=PASS",
  "LIAN_CANONICAL_FRAMES=PASS",
  "RIVAL_CANONICAL_FRAMES=PASS",
  "WINDOWS_EXPORT=PASS",
  "VISUAL_CUTOVER=PASS",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=81%",
  "PROJECT_PROGRESS=58%",
  "BUILD=$winOut",
  "SHA256=$sha",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C50_CANONICAL_VISUAL_CUTOVER_GATE=PASS"
Write-Host "Tehkne Solutions"
