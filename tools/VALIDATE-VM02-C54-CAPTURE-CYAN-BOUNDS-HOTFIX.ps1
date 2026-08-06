param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
$output = Join-Path $RepoRoot "artifacts\vm02-c54\base00-godot-bench-1920x1080.png"

if (-not (Test-Path $output)) {
  throw "VM02_C54_CAPTURE_CONTENT_BOUNDS=BLOCKED missing_capture"
}

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::FromFile($output)
$cyanMinX = [int]::MaxValue
$cyanMinY = [int]::MaxValue
$cyanMaxX = -1
$cyanMaxY = -1
$cyanCount = 0

try {
  if ($bitmap.Width -ne 1920 -or $bitmap.Height -ne 1080) {
    throw "VM02_C54_CAPTURE_DIMENSIONS=BLOCKED size=$($bitmap.Width)x$($bitmap.Height)"
  }

  for ($y = 0; $y -lt $bitmap.Height; $y += 2) {
    for ($x = 0; $x -lt $bitmap.Width; $x += 2) {
      $pixel = $bitmap.GetPixel($x, $y)
      $blueLead = [int]$pixel.B - [int]$pixel.G

      # Cyan envelope: blue must lead green. This explicitly excludes
      # the canonical green baseline, whose green channel leads blue.
      if (
        $pixel.R -le 150 -and
        $pixel.G -ge 150 -and
        $pixel.B -ge 190 -and
        $blueLead -ge 5
      ) {
        $cyanCount++
        if ($x -lt $cyanMinX) { $cyanMinX = $x }
        if ($x -gt $cyanMaxX) { $cyanMaxX = $x }
        if ($y -lt $cyanMinY) { $cyanMinY = $y }
        if ($y -gt $cyanMaxY) { $cyanMaxY = $y }
      }
    }
  }
} finally {
  $bitmap.Dispose()
}

Write-Host "VM02_C54_CAPTURE_DIMENSIONS=PASS size=1920x1080"

if ($cyanCount -lt 40) {
  throw "VM02_C54_CAPTURE_CONTENT_BOUNDS=BLOCKED cyan_pixels=$cyanCount"
}

if (
  $cyanMinX -lt 450 -or $cyanMinX -gt 800 -or
  $cyanMaxX -lt 1100 -or $cyanMaxX -gt 1500 -or
  $cyanMinY -lt 500 -or $cyanMinY -gt 800 -or
  $cyanMaxY -lt 700 -or $cyanMaxY -gt 900
) {
  throw "VM02_C54_CAPTURE_CONTENT_BOUNDS=BLOCKED bounds=$cyanMinX,$cyanMinY,$cyanMaxX,$cyanMaxY"
}

$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C54_CAPTURE_CYAN_CLASSIFIER=PASS blue_leads_green"
Write-Host "VM02_C54_CAPTURE_CONTENT_BOUNDS=PASS bounds=$cyanMinX,$cyanMinY,$cyanMaxX,$cyanMaxY"
Write-Host "VM02_C54_VISUAL_PROOF_SHA256=$sha"
Write-Host "VM02_C54_CAPTURE_BOUNDS_HOTFIX=PASS"
Write-Host "Tehkne Solutions"
