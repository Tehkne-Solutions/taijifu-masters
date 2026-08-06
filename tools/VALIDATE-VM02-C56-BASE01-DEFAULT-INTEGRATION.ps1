param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$manifestPath = Join-Path $RepoRoot "assets\modular_fighters\base_01\manifest.json"
$qaPath = Join-Path $RepoRoot "assets\modular_fighters\base_01\qa\BASE01_DEFAULT_IDENTITY_MODULES_v1.0.0.qa.json"
$assemblerPath = Join-Path $RepoRoot "scripts\characters\modular_fighter_assembler.gd"

$required = @(
  $manifestPath,
  $qaPath,
  $assemblerPath,
  (Join-Path $RepoRoot "assets\modular_fighters\base_01\palettes\skin_tone_03_warm.json"),
  (Join-Path $RepoRoot "assets\modular_fighters\base_01\face\face_01_balanced.png"),
  (Join-Path $RepoRoot "assets\modular_fighters\base_01\eyes\eyes_01_focused.png"),
  (Join-Path $RepoRoot "assets\modular_fighters\base_01\brows\brows_01_focused.png")
)

$missing = @($required | Where-Object { -not (Test-Path $_) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C56_MISSING=$_" }
  Write-Host "VM02_C56_BASE01_DEFAULT_INTEGRATION=BLOCKED"
  exit 2
}
Write-Host "VM02_C56_REQUIRED_FILES=PASS"

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$qa = Get-Content $qaPath -Raw | ConvertFrom-Json

if ($manifest.pack_id -ne "BASE01_DEFAULT_IDENTITY_MODULES" -or $manifest.version -ne "1.0.0") {
  throw "VM02_C56_MANIFEST_IDENTITY=BLOCKED"
}
if ($manifest.authoring.canvas[0] -ne 1024 -or $manifest.authoring.canvas[1] -ne 1024 -or $manifest.authoring.mode -ne "RGBA") {
  throw "VM02_C56_AUTHORING_CONTRACT=BLOCKED"
}
if ([math]::Abs([double]$manifest.authoring.pivot[0] - 0.5) -gt 0.0001 -or [math]::Abs([double]$manifest.authoring.pivot[1] - 0.92) -gt 0.0001) {
  throw "VM02_C56_PIVOT=BLOCKED"
}
if ($manifest.authoring.contact_sheet_runtime_source) {
  throw "VM02_C56_CONTACT_SHEET_RUNTIME_SOURCE=BLOCKED"
}
Write-Host "VM02_C56_MANIFEST_CONTRACT=PASS"

$expected = @{
  "face_01_balanced" = "d8bc0218b6104d2095e20a074fa4e0a23d428d1bf71e91fcac7139374b3504d9"
  "eyes_01_focused" = "7517e6d14cef106fbe782736524321b992ea3088486498fc24e71f1e158419a9"
  "brows_01_focused" = "44fa5d30e0963582b5cf2d877b7a61a6d68f8028b9a2da19cbba9a73afc80225"
}

foreach ($moduleId in $expected.Keys) {
  $module = $manifest.modules.$moduleId
  if ($null -eq $module) { throw "VM02_C56_MODULE_CONTRACT=BLOCKED module=$moduleId" }
  $path = Join-Path $RepoRoot ($module.path -replace '/', '\')
  $actual = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
  if ($actual -ne $expected[$moduleId]) {
    throw "VM02_C56_SHA256=BLOCKED module=$moduleId expected=$($expected[$moduleId]) actual=$actual"
  }
  Write-Host "VM02_C56_SHA256=PASS module=$moduleId"
}

if ($qa.status -ne "PASS_CANDIDATE") {
  throw "VM02_C56_CANDIDATE_QA=BLOCKED"
}
if ($qa.checks.required_modules -ne "PASS" -or $qa.checks.default_reconstruction -ne "PASS" -or $qa.checks.authored_alignment -ne "PASS" -or $qa.checks.flipped_alignment -ne "PASS" -or $qa.checks.gameplay_scale_132px -ne "PASS") {
  throw "VM02_C56_CANDIDATE_CHECKS=BLOCKED"
}
Write-Host "VM02_C56_CANDIDATE_QA=PASS"

$assembler = Get-Content $assemblerPath -Raw
if ($assembler -notmatch 'assemble_base01_default_identity' -or $assembler -notmatch 'BASE01_MANIFEST_PATH') {
  throw "VM02_C56_RUNTIME_ASSEMBLER=BLOCKED"
}
Write-Host "VM02_C56_RUNTIME_ASSEMBLER=PASS"

if ($manifest.qa.owner_review -ne "PASS" -or $qa.owner_approval -ne "PASS") {
  Write-Host "VM02_C56_OWNER_REVIEW=PENDING"
  Write-Host "VM02_C56_BASE01_DEFAULT_INTEGRATION=BLOCKED_OWNER_REVIEW"
  exit 3
}

Write-Host "VM02_C56_OWNER_REVIEW=PASS"
Write-Host "VM02_C56_BASE01_DEFAULT_INTEGRATION=PASS"
Write-Host "SIGNATURE=Tehkné Solutions"
