param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$Asset = Join-Path $RepoRoot "assets\modular_fighters\base_00\base_fighter_v1_master.png"
$QaPath = Join-Path $RepoRoot "assets\modular_fighters\base_00\qa\base_fighter_v1_master.qa.json"
$ManifestPath = Join-Path $RepoRoot "assets\modular_fighters\base_00\manifest.json"
$FoundationGate = Join-Path $RepoRoot "tools\RUN-VM02-C50-BASE00-MODULAR-FIGHTER-FOUNDATION-GATE.ps1"
$ExpectedSha256 = "fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe"

foreach ($required in @($Asset, $QaPath, $ManifestPath, $FoundationGate)) {
  if (-not (Test-Path $required)) {
    throw "VM02_C52_REQUIRED_FILES=BLOCKED missing=$required"
  }
}
Write-Host "VM02_C52_REQUIRED_FILES=PASS"

$sha = (Get-FileHash $Asset -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sha -ne $ExpectedSha256) {
  throw "VM02_C52_SHA256=BLOCKED expected=$ExpectedSha256 actual=$sha"
}
Write-Host "VM02_C52_SHA256=PASS sha256=$sha"

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::FromFile($Asset)
try {
  if ($bitmap.Width -ne 1024 -or $bitmap.Height -ne 1024) {
    throw "VM02_C52_CANVAS=BLOCKED size=$($bitmap.Width)x$($bitmap.Height)"
  }
  $alphaCapable = (($bitmap.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::Alpha) -ne 0) -or (($bitmap.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::PAlpha) -ne 0)
  if (-not $alphaCapable) { throw "VM02_C52_RGBA=BLOCKED pixel_format=$($bitmap.PixelFormat)" }
  foreach ($point in @(@(0,0), @(1023,0), @(0,1023), @(1023,1023))) {
    if ($bitmap.GetPixel($point[0], $point[1]).A -ne 0) {
      throw "VM02_C52_TRANSPARENCY=BLOCKED point=$($point[0]),$($point[1])"
    }
  }
} finally {
  $bitmap.Dispose()
}
Write-Host "VM02_C52_CANVAS=PASS size=1024x1024"
Write-Host "VM02_C52_RGBA_TRANSPARENCY=PASS"

$qa = Get-Content $QaPath -Raw | ConvertFrom-Json
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
if ($qa.status -ne "PASS" -or $qa.checks.human_visual_review -ne "PASS") {
  throw "VM02_C52_QA=BLOCKED status=$($qa.status)"
}
if ($qa.last_visible_y -ne 941 -or [math]::Abs([double]$qa.computed_center_x - 511.5) -gt 1.0) {
  throw "VM02_C52_BASELINE=BLOCKED last_visible_y=$($qa.last_visible_y) center=$($qa.computed_center_x)"
}
if ($manifest.production_status -ne "approved_canonical_master" -or $manifest.asset_id -ne "base_fighter_v1") {
  throw "VM02_C52_MANIFEST=BLOCKED"
}
Write-Host "VM02_C52_QA=PASS"
Write-Host "VM02_C52_MANIFEST=PASS"
Write-Host "VM02_C52_PIVOT_BASELINE=PASS pivot=0.5,0.92"

Write-Host "VM02_C52_FOUNDATION_HANDOFF=BEGIN"
& powershell -NoProfile -ExecutionPolicy Bypass -File $FoundationGate -RepoRoot $RepoRoot
if ($LASTEXITCODE -ne 0) { throw "VM02_C52_FOUNDATION_HANDOFF=BLOCKED exit=$LASTEXITCODE" }
Write-Host "VM02_C52_FOUNDATION_HANDOFF=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C52-BASE00-ART-MASTER-INTEGRATION",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "ASSET=PASS",
  "CANVAS=1024x1024",
  "RGBA_TRANSPARENCY=PASS",
  "VISUAL_QA=PASS",
  "PIVOT_BASELINE=PASS",
  "FOUNDATION_HANDOFF=PASS",
  "SHA256=$sha",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=81%",
  "PROJECT_PROGRESS=58%",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C52_BASE00_ART_MASTER_INTEGRATION_GATE=PASS"
Write-Host "Tehkne Solutions"
