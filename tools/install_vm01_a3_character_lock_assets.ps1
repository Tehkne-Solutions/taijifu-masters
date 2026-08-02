param(
  [Parameter(Mandatory=$true)]
  [string]$BundleRoot,
  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"

$Target = Join-Path $RepoRoot "assets\characters\lian_wu\character_lock"
New-Item -ItemType Directory -Force -Path $Target | Out-Null

$NeutralSource = Join-Path $BundleRoot "assets\characters\lian_wu\character_lock\lian_wu_neutral.png"
$StanceSource = Join-Path $BundleRoot "assets\characters\lian_wu\character_lock\lian_wu_combat_stance.png"
$NeutralTarget = Join-Path $Target "lian_wu_neutral.png"
$StanceTarget = Join-Path $Target "lian_wu_combat_stance.png"

Copy-Item $NeutralSource $NeutralTarget -Force
Copy-Item $StanceSource $StanceTarget -Force

$NeutralHash = (Get-FileHash $NeutralTarget -Algorithm SHA256).Hash.ToLower()
$StanceHash = (Get-FileHash $StanceTarget -Algorithm SHA256).Hash.ToLower()

$ExpectedNeutral = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
$ExpectedStance = "c8e6cd1feece7c2a54cf2279085c2a4bb33338dd6a3dcb3e4d5a2402b537631c"

if ($NeutralHash -ne $ExpectedNeutral) {
  throw "Neutral SHA256 mismatch: $NeutralHash"
}
if ($StanceHash -ne $ExpectedStance) {
  throw "Combat stance SHA256 mismatch: $StanceHash"
}

Write-Host "VM01_A3_ASSET_MATERIALIZATION=PASS"
Write-Host "Neutral: $NeutralHash"
Write-Host "Combat stance: $StanceHash"
