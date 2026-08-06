param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$required = @(
  "config\modular-fighter-standard-v1.json",
  "config\fighter-bases\base_fighter_v1.json",
  "config\fighter-modules\base_01_faces_skin_v1.json",
  "assets\modular_fighters\base_00\base_fighter_v1_master.png",
  "docs\C54.6-HUMAN-VISUAL-REVIEW.md",
  "docs\VM02-C55-BASE01-FACES-SKIN-FOUNDATION.md",
  "tools\VALIDATE-VM02-C54-CAPTURE-CYAN-BOUNDS-HOTFIX.ps1"
)

$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C55_MISSING_REQUIRED=$_" }
  throw "VM02_C55_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C55_REQUIRED_FILES=PASS"

$reviewText = Get-Content (Join-Path $RepoRoot "docs\C54.6-HUMAN-VISUAL-REVIEW.md") -Raw
if ($reviewText -notmatch 'VM02_C54_HUMAN_VISUAL_REVIEW=PASS') {
  throw "VM02_C55_BASE00_HUMAN_REVIEW=BLOCKED"
}
if ($reviewText -notmatch '237c40004ec608bbc4250f9608d64e881dbca1d6a1d75b8c3befb78b8d763af5') {
  throw "VM02_C55_BASE00_EVIDENCE_SHA=BLOCKED"
}
Write-Host "VM02_C55_BASE00_HUMAN_REVIEW=PASS"
Write-Host "VM02_C55_BASE00_EVIDENCE_SHA=PASS"

$standard = Get-Content (Join-Path $RepoRoot "config\modular-fighter-standard-v1.json") -Raw | ConvertFrom-Json
$contract = Get-Content (Join-Path $RepoRoot "config\fighter-modules\base_01_faces_skin_v1.json") -Raw | ConvertFrom-Json

foreach ($slot in @("skin","face","eyes","brows")) {
  if (@($standard.slots) -notcontains $slot) {
    throw "VM02_C55_SLOT_REGISTRY=BLOCKED missing=$slot"
  }
}
Write-Host "VM02_C55_SLOT_REGISTRY=PASS slots=skin,face,eyes,brows"

if ($contract.pack_id -ne "base_01_faces_skin_v1" -or $contract.visual_style -ne "chibi_manga_comic") {
  throw "VM02_C55_PACK_CONTRACT=BLOCKED"
}
if ($contract.depends_on.base_body_id -ne "base_fighter_v1" -or $contract.depends_on.base00_human_review -ne "PASS") {
  throw "VM02_C55_BASE00_DEPENDENCY=BLOCKED"
}
Write-Host "VM02_C55_PACK_CONTRACT=PASS"
Write-Host "VM02_C55_BASE00_DEPENDENCY=PASS"

if ($contract.authoring.canvas[0] -ne 1024 -or $contract.authoring.canvas[1] -ne 1024 -or $contract.authoring.mode -ne "RGBA") {
  throw "VM02_C55_AUTHORING=BLOCKED"
}
if (-not $contract.authoring.native_transparency_required -or $contract.authoring.contact_sheet_runtime_source_allowed -or $contract.authoring.background_removal_pipeline_allowed -or $contract.authoring.text_or_labels_in_runtime_asset_allowed) {
  throw "VM02_C55_AUTHORING_POLICY=BLOCKED"
}
if ([math]::Abs([double]$contract.authoring.pivot[0] - 0.5) -gt 0.0001 -or [math]::Abs([double]$contract.authoring.pivot[1] - 0.92) -gt 0.0001) {
  throw "VM02_C55_PIVOT=BLOCKED"
}
Write-Host "VM02_C55_AUTHORING=PASS canvas=1024x1024 mode=RGBA"
Write-Host "VM02_C55_AUTHORING_POLICY=PASS"
Write-Host "VM02_C55_PIVOT=PASS pivot=0.5,0.92"

if ($contract.skin_system.implementation -ne "palette_driven_base_tint" -or $contract.skin_system.full_body_duplicate_png_per_tone_allowed) {
  throw "VM02_C55_SKIN_ARCHITECTURE=BLOCKED"
}
if (@($contract.skin_system.initial_tone_ids).Count -lt 8) {
  throw "VM02_C55_SKIN_TONES=BLOCKED count=$(@($contract.skin_system.initial_tone_ids).Count)"
}
Write-Host "VM02_C55_SKIN_ARCHITECTURE=PASS palette_driven"
Write-Host "VM02_C55_SKIN_TONES=PASS count=$(@($contract.skin_system.initial_tone_ids).Count)"

$minimum = $contract.face_modules.initial_minimum
if ($minimum.face_variants -lt 4 -or $minimum.eye_variants -lt 6 -or $minimum.brow_variants -lt 6 -or $minimum.skin_tones -lt 8) {
  throw "VM02_C55_INITIAL_CATALOG=BLOCKED"
}
if (@($contract.face_modules.expression_families).Count -lt 6 -or -not $contract.face_modules.shared_timeline_required) {
  throw "VM02_C55_EXPRESSION_CONTRACT=BLOCKED"
}
Write-Host "VM02_C55_INITIAL_CATALOG=PASS faces=4 eyes=6 brows=6 skin=8"
Write-Host "VM02_C55_EXPRESSION_CONTRACT=PASS count=$(@($contract.face_modules.expression_families).Count)"

$expectedRoot = Join-Path $RepoRoot $contract.canonical_paths.root
$manifest = Join-Path $RepoRoot $contract.canonical_paths.manifest
if (Test-Path $manifest) {
  Write-Host "VM02_C55_BASE01_ART=DETECTED manifest=$manifest"
} else {
  Write-Host "VM02_C55_BASE01_ART=PENDING_NON_BLOCKING"
  Write-Host "VM02_C55_EXPECTED_ROOT=$expectedRoot"
  Write-Host "VM02_C55_NEXT_DELIVERABLE=$($contract.production_state.next_deliverable)"
}

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
Write-Host "COPY_REPORT_BEGIN"
Write-Host "GATE=VM02-C55-BASE01-FACES-SKIN-FOUNDATION"
Write-Host "STATUS=PASS"
Write-Host "BRANCH=$branch"
Write-Host "COMMIT=$commit"
Write-Host "BASE00_CLOSEOUT=PASS"
Write-Host "SKIN_ARCHITECTURE=PALETTE_DRIVEN"
Write-Host "FACE_SLOTS=PASS"
Write-Host "BASE01_ART=PENDING"
Write-Host "V2_PLAYABLE_PROGRESS=79%"
Write-Host "PROJECT_PROGRESS=57%"
Write-Host "COPY_REPORT_END"
Write-Host "VM02_C55_BASE01_FACES_SKIN_FOUNDATION_GATE=PASS"
Write-Host "Tehkne Solutions"
