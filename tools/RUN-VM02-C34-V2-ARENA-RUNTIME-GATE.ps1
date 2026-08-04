param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$arenaRoot = Join-Path $RepoRoot "assets\pack_03_stages\mountain_dojo_night"
$runtimeScript = Join-Path $RepoRoot "scripts\vertical_slice\canonical_arena_parallax.gd"
$environmentScript = Join-Path $RepoRoot "scripts\vertical_slice\first_playable_environment_art.gd"
$progressPath = Join-Path $RepoRoot "config\v2-production-progress.json"
$reportLib = Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1"

foreach ($file in @($runtimeScript, $environmentScript, $progressPath, $reportLib)) {
  if (-not (Test-Path $file)) { throw "VM02_C34_REQUIRED_FILES=BLOCKED missing=$file" }
}
Write-Host "VM02_C34_REQUIRED_FILES=PASS"

$required = @("background.png", "midground.png", "foreground.png", "collision.json", "lighting.json", "manifest.json")
$missing = @()
foreach ($name in $required) {
  if (-not (Test-Path (Join-Path $arenaRoot $name))) { $missing += $name }
}

$arenaImported = $missing.Count -eq 0
Write-Host ("VM02_C34_ARENA_IMPORTED=" + $(if ($arenaImported) { "PASS" } else { "BLOCKED" }))
Write-Host "VM02_C34_ARENA_FILE_COUNT=$($required.Count - $missing.Count)/$($required.Count)"
if ($missing.Count -gt 0) {
  foreach ($name in $missing) { Write-Host "VM02_C34_MISSING_FILE=$name" }
}

$runtimeText = Get-Content $runtimeScript -Raw
$environmentText = Get-Content $environmentScript -Raw

$layerContract = ($runtimeText -match 'background\.png') -and
                 ($runtimeText -match 'midground\.png') -and
                 ($runtimeText -match 'foreground\.png') -and
                 ($runtimeText -match '0\.18') -and
                 ($runtimeText -match '0\.48') -and
                 ($runtimeText -match '1\.0')
Write-Host ("VM02_C34_PARALLAX_CONTRACT=" + $(if ($layerContract) { "PASS" } else { "BLOCKED" }))

$bindingContract = ($environmentText -match 'CanonicalArenaParallax') -and
                   ($environmentText -match '_canonical_arena_ready') -and
                   ($environmentText -match '_install_canonical_arena')
Write-Host ("VM02_C34_RUNTIME_BINDING=" + $(if ($bindingContract) { "PASS" } else { "BLOCKED" }))

$placeholderRetire = ($environmentText -match 'if _canonical_arena_active:\s*\n\s*return') -and
                     ($environmentText -match 'if _canonical_arena_active:\s*\n\s*_install_canonical_arena')
Write-Host ("VM02_C34_PROCEDURAL_RETIREMENT=" + $(if ($placeholderRetire) { "PASS" } else { "BLOCKED" }))

$manifestValid = $false
$groundAligned = $false
if ($arenaImported) {
  try {
    $manifest = Get-Content (Join-Path $arenaRoot "manifest.json") -Raw | ConvertFrom-Json
    $collision = Get-Content (Join-Path $arenaRoot "collision.json") -Raw | ConvertFrom-Json
    $manifestValid = ($manifest.signature -eq "Tehkné Solutions") -and ($manifest.arena_id -eq "mountain_dojo_night")
    $groundAligned = ([int]$collision.ground_y -eq 820) -and ([int]$manifest.runtime_contract.ground_y -eq 820)
  } catch {
    $manifestValid = $false
    $groundAligned = $false
  }
}
Write-Host ("VM02_C34_MANIFEST_CONTRACT=" + $(if ($manifestValid) { "PASS" } else { "BLOCKED" }))
Write-Host ("VM02_C34_GROUND_ALIGNMENT=" + $(if ($groundAligned) { "PASS" } else { "BLOCKED" }))

$pipelineReady = $layerContract -and $bindingContract -and $placeholderRetire
if (-not $pipelineReady) { throw "VM02_C34_RUNTIME_PIPELINE=BLOCKED" }
Write-Host "VM02_C34_RUNTIME_PIPELINE=PASS"

$canonicalReady = $arenaImported -and $manifestValid -and $groundAligned
Write-Host ("VM02_C34_CANONICAL_RUNTIME_READY=" + $(if ($canonicalReady) { "PASS" } else { "BLOCKED" }))
Write-Host "VM02_C34_V2_ARENA_RUNTIME_GATE=PASS"

. $reportLib
$progress = Get-Content $progressPath -Raw | ConvertFrom-Json
$branchName = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C34-V2-ARENA-RUNTIME-BINDING" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  ARENA_IMPORTED=$(if ($arenaImported) { "PASS" } else { "BLOCKED" })
  FILE_COUNT="$($required.Count - $missing.Count)/$($required.Count)"
  PARALLAX_CONTRACT=$(if ($layerContract) { "PASS" } else { "BLOCKED" })
  RUNTIME_BINDING=$(if ($bindingContract) { "PASS" } else { "BLOCKED" })
  PROCEDURAL_RETIREMENT=$(if ($placeholderRetire) { "PASS" } else { "BLOCKED" })
  MANIFEST_CONTRACT=$(if ($manifestValid) { "PASS" } else { "BLOCKED" })
  GROUND_ALIGNMENT=$(if ($groundAligned) { "PASS" } else { "BLOCKED" })
  CANONICAL_RUNTIME_READY=$(if ($canonicalReady) { "PASS" } else { "BLOCKED" })
  PIPELINE_READY="PASS"
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard

# Tehkné Solutions
