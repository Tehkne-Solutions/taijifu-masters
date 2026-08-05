param(
  [Parameter(Mandatory = $true)]
  [string]$PackagePath,
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$ExpectedSha256 = "fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe"
$PackagePath = (Resolve-Path $PackagePath).Path
$TempRoot = Join-Path $env:TEMP ("taijifu-base00-" + [guid]::NewGuid().ToString("N"))

try {
  New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null
  Expand-Archive -Path $PackagePath -DestinationPath $TempRoot -Force

  $SourceAsset = Join-Path $TempRoot "assets\modular_fighters\base_00\base_fighter_v1_master.png"
  $SourceQa = Join-Path $TempRoot "qa\base_fighter_v1_master.qa.json"
  $SourceManifest = Join-Path $TempRoot "manifest.json"

  foreach ($required in @($SourceAsset, $SourceQa, $SourceManifest)) {
    if (-not (Test-Path $required)) {
      throw "VM02_C52_PACKAGE_CONTRACT=BLOCKED missing=$required"
    }
  }
  Write-Host "VM02_C52_PACKAGE_CONTRACT=PASS"

  $ActualSha256 = (Get-FileHash $SourceAsset -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($ActualSha256 -ne $ExpectedSha256) {
    throw "VM02_C52_ASSET_SHA256=BLOCKED expected=$ExpectedSha256 actual=$ActualSha256"
  }
  Write-Host "VM02_C52_ASSET_SHA256=PASS sha256=$ActualSha256"

  Add-Type -AssemblyName System.Drawing
  $bitmap = [System.Drawing.Bitmap]::FromFile($SourceAsset)
  try {
    if ($bitmap.Width -ne 1024 -or $bitmap.Height -ne 1024) {
      throw "VM02_C52_CANVAS=BLOCKED size=$($bitmap.Width)x$($bitmap.Height)"
    }
    Write-Host "VM02_C52_CANVAS=PASS size=1024x1024"

    $alphaCapable = (($bitmap.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::Alpha) -ne 0) -or (($bitmap.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::PAlpha) -ne 0)
    if (-not $alphaCapable) { throw "VM02_C52_RGBA=BLOCKED pixel_format=$($bitmap.PixelFormat)" }

    foreach ($point in @(@(0,0), @(1023,0), @(0,1023), @(1023,1023))) {
      if ($bitmap.GetPixel($point[0], $point[1]).A -ne 0) {
        throw "VM02_C52_TRANSPARENT_CORNERS=BLOCKED point=$($point[0]),$($point[1])"
      }
    }
    Write-Host "VM02_C52_RGBA=PASS"
    Write-Host "VM02_C52_TRANSPARENT_CORNERS=PASS"
  } finally {
    $bitmap.Dispose()
  }

  $qa = Get-Content $SourceQa -Raw | ConvertFrom-Json
  if ($qa.status -ne "PASS" -or $qa.checks.human_visual_review -ne "PASS") {
    throw "VM02_C52_VISUAL_QA=BLOCKED status=$($qa.status) review=$($qa.checks.human_visual_review)"
  }
  if ($qa.last_visible_y -ne 941 -or [math]::Abs([double]$qa.computed_center_x - 511.5) -gt 1.0) {
    throw "VM02_C52_PIVOT_BASELINE=BLOCKED baseline=$($qa.last_visible_y) center=$($qa.computed_center_x)"
  }
  Write-Host "VM02_C52_VISUAL_QA=PASS"
  Write-Host "VM02_C52_PIVOT_BASELINE=PASS pivot=0.5,0.92"

  $DestinationRoot = Join-Path $RepoRoot "assets\modular_fighters\base_00"
  $QaRoot = Join-Path $DestinationRoot "qa"
  New-Item -ItemType Directory -Force -Path $DestinationRoot, $QaRoot | Out-Null

  Copy-Item $SourceAsset (Join-Path $DestinationRoot "base_fighter_v1_master.png") -Force
  Copy-Item $SourceQa (Join-Path $QaRoot "base_fighter_v1_master.qa.json") -Force
  Copy-Item $SourceManifest (Join-Path $DestinationRoot "manifest.json") -Force

  Write-Host "VM02_C52_CANONICAL_COPY=PASS destination=$DestinationRoot"

  $Gate = Join-Path $RepoRoot "tools\RUN-VM02-C52-BASE00-ART-MASTER-INTEGRATION-GATE.ps1"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Gate -RepoRoot $RepoRoot
  if ($LASTEXITCODE -ne 0) { throw "VM02_C52_GATE_HANDOFF=BLOCKED exit=$LASTEXITCODE" }
  Write-Host "VM02_C52_GATE_HANDOFF=PASS"
  Write-Host "Tehkne Solutions"
} finally {
  Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
