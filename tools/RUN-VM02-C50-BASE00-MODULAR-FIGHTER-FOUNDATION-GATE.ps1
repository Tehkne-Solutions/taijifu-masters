param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "config\modular-fighter-standard-v1.json",
  "config\fighter-bases\base_fighter_v1.json",
  "scripts\characters\modular_fighter_profile.gd",
  "scripts\characters\modular_fighter_assembler.gd"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C50_BASE00_MISSING_REQUIRED=$_" }
  throw "VM02_C50_BASE00_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C50_BASE00_REQUIRED_FILES=PASS"

$standard = Get-Content (Join-Path $RepoRoot "config\modular-fighter-standard-v1.json") -Raw | ConvertFrom-Json
$base = Get-Content (Join-Path $RepoRoot "config\fighter-bases\base_fighter_v1.json") -Raw | ConvertFrom-Json

if ($standard.visual_target.style -ne "chibi_manga_comic") { throw "VM02_C50_BASE00_STYLE=BLOCKED" }
if ($base.visual_style -ne "chibi_manga_comic") { throw "VM02_C50_BASE00_STYLE=BLOCKED" }
Write-Host "VM02_C50_BASE00_STYLE=PASS style=chibi_manga_comic"

if ($base.source.canvas[0] -ne 1024 -or $base.source.canvas[1] -ne 1024 -or $base.source.mode -ne "RGBA") {
  throw "VM02_C50_BASE00_SOURCE_CONTRACT=BLOCKED"
}
if (-not $base.source.native_transparency_required -or $base.source.background_allowed -or $base.source.text_allowed) {
  throw "VM02_C50_BASE00_SOURCE_CONTRACT=BLOCKED"
}
if ($base.source.equipment_baked_into_body_allowed -or $base.source.hair_baked_into_body_allowed -or $base.source.weapon_baked_into_body_allowed) {
  throw "VM02_C50_BASE00_MODULARITY=BLOCKED"
}
Write-Host "VM02_C50_BASE00_SOURCE_CONTRACT=PASS canvas=1024x1024 mode=RGBA"
Write-Host "VM02_C50_BASE00_MODULARITY=PASS"

$requiredBones = @("root","pelvis","torso","chest","head","hand_l","hand_r","foot_l","foot_r","weapon_main_anchor","hair_back_anchor")
$bones = @($base.rig_contract.bones)
foreach ($bone in $requiredBones) {
  if ($bone -eq "root") { if ($base.rig_contract.root -ne "root") { throw "VM02_C50_BASE00_RIG_CONTRACT=BLOCKED root" }; continue }
  if ($bones -notcontains $bone) { throw "VM02_C50_BASE00_RIG_CONTRACT=BLOCKED missing=$bone" }
}
if (-not $base.rig_contract.shared_animation_source -or -not $base.rig_contract.module_attachment_by_slot) {
  throw "VM02_C50_BASE00_RIG_CONTRACT=BLOCKED"
}
Write-Host "VM02_C50_BASE00_RIG_CONTRACT=PASS"

$assembler = Get-Content (Join-Path $RepoRoot "scripts\characters\modular_fighter_assembler.gd") -Raw
$assemblerContract = [ordered]@{
  CLASS_NAME = 'class_name ModularFighterAssembler'
  CONFIGURE_ENTRY = 'func configure(profile) -> PackedStringArray:'
  PROFILE_METHOD_CHECK = '_profile.has_method("validate_against_standard")'
  PROFILE_RUNTIME_VALIDATION = '_profile.call("validate_against_standard")'
  VALIDATION_RESULT_TYPE = 'TYPE_PACKED_STRING_ARRAY'
  VISUAL_ATTACHMENT = 'func attach_visual_module(slot: StringName, node: CanvasItem) -> bool:'
  READY_ACCESSOR = 'func is_ready_for_render() -> bool:'
  PROFILE_ID_ACCESSOR = 'func profile_id() -> StringName:'
}
foreach ($entry in $assemblerContract.GetEnumerator()) {
  if (-not $assembler.Contains([string]$entry.Value)) {
    throw "VM02_C50_BASE00_ASSEMBLER_CONTRACT=BLOCKED missing=$($entry.Key)"
  }
  Write-Host "VM02_C50_BASE00_ASSEMBLER_$($entry.Key)=PASS"
}
if ($assembler -match 'var\s+_profile\s*:\s*ModularFighterProfile' -or $assembler -match 'configure\s*\([^)]*:\s*ModularFighterProfile') {
  throw "VM02_C50_BASE00_ASSEMBLER_COMPILE_TIME_PROFILE_TYPE=BLOCKED"
}
Write-Host "VM02_C50_BASE00_ASSEMBLER_COMPILE_TIME_PROFILE_TYPE=RETIRED"
Write-Host "VM02_C50_BASE00_ASSEMBLER_CONTRACT=PASS"

$master = Join-Path $RepoRoot $base.source.expected_master
if (Test-Path $master) {
  Write-Host "VM02_C50_BASE00_ART_MASTER=PASS path=$master"
} else {
  Write-Host "VM02_C50_BASE00_ART_MASTER=BLOCKED"
  Write-Host "VM02_C50_BASE00_EXPECTED_MASTER=$master"
  Write-Host "VM02_C50_BASE00_NEXT_ACTION=produce_clean_neutral_body_master"
}

Write-Host "VM02_C50_BASE00_FOUNDATION=PASS"
Write-Host "Tehkne Solutions"
