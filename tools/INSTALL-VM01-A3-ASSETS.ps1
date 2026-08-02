param(
  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = ".",
  [Parameter(Mandatory=$false)]
  [string]$BundleRoot = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($BundleRoot)) {
  # When this script is copied/extracted into the repository, the bundle root is the repo itself.
  $BundleRoot = (Split-Path -Parent $PSScriptRoot)
}
$BundleRoot = (Resolve-Path $BundleRoot).Path

$relative = "assets\characters\lian_wu\character_lock"
$sourceDir = Join-Path $BundleRoot $relative
$targetDir = Join-Path $RepoRoot $relative
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$expected = @{
  "lian_wu_neutral.png" = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
  "lian_wu_combat_stance.png" = "c8e6cd1feece7c2a54cf2279085c2a4bb33338dd6a3dcb3e4d5a2402b537631c"
}

foreach ($name in $expected.Keys) {
  $src = Join-Path $sourceDir $name
  $dst = Join-Path $targetDir $name
  if (-not (Test-Path $src)) {
    throw "VM01_A3_ASSET_MATERIALIZATION=BLOCKED missing source: $src"
  }

  $srcFull = [System.IO.Path]::GetFullPath($src)
  $dstFull = [System.IO.Path]::GetFullPath($dst)

  if (-not [string]::Equals($srcFull, $dstFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    Copy-Item $srcFull $dstFull -Force
  } else {
    Write-Host "SKIP_COPY_ALREADY_MATERIALIZED $name"
  }

  $actual = (Get-FileHash $dstFull -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected[$name]) {
    throw "VM01_A3_ASSET_MATERIALIZATION=BLOCKED SHA256 mismatch for $name`nExpected: $($expected[$name])`nActual:   $actual"
  }
  Write-Host "HASH_PASS $name $actual"
}

Write-Host "VM01_A3_ASSET_MATERIALIZATION=PASS"
Write-Host "RepoRoot=$RepoRoot"
