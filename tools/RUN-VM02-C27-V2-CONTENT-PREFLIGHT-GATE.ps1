param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$contractPath = Join-Path $RepoRoot "config\v2-playable-content-contract.json"
$reportLib = Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1"
$required = @(
  $contractPath,
  $reportLib,
  (Join-Path $RepoRoot "scripts\runtime\first_playable_round_match_runtime.gd"),
  (Join-Path $RepoRoot "scenes\runtime\first_playable_round_match_runtime.tscn")
)
foreach ($file in $required) {
  if (-not (Test-Path $file)) { throw "VM02_C27_REQUIRED_FILES=BLOCKED missing=$file" }
}
Write-Host "VM02_C27_REQUIRED_FILES=PASS"

try {
  $contract = Get-Content $contractPath -Raw | ConvertFrom-Json
} catch {
  throw "VM02_C27_CONTRACT_PARSE=BLOCKED"
}
Write-Host "VM02_C27_CONTRACT_PARSE=PASS"

if ($contract.signature -ne "Tehkné Solutions") { throw "VM02_C27_SIGNATURE=BLOCKED" }
if ($contract.milestone -ne "v.2 playable") { throw "VM02_C27_MILESTONE=BLOCKED" }
if ($contract.definition_of_done.canonical_fighters -ne 2) { throw "VM02_C27_FIGHTER_TARGET=BLOCKED" }
if ($contract.definition_of_done.canonical_arenas -ne 1) { throw "VM02_C27_ARENA_TARGET=BLOCKED" }
Write-Host "VM02_C27_CONTRACT_SCHEMA=PASS"

$lianRoot = Join-Path $RepoRoot "assets\pack_01_characters\lian_wu"
$lianPresent = Test-Path $lianRoot
Write-Host ("VM02_C27_LIAN_CANONICAL_ROOT=" + $(if ($lianPresent) { "PASS" } else { "BLOCKED" }))

$rivalProxy = [bool]$contract.rival.must_replace_proxy
$stagePrototype = [bool]$contract.arena.must_replace_prototype
$rivalCanonicalReady = -not $rivalProxy
$arenaCanonicalReady = -not $stagePrototype

Write-Host "VM02_C27_RIVAL_PROXY_DECLARED=PASS"
Write-Host "VM02_C27_STAGE_PROTOTYPE_DECLARED=PASS"
Write-Host ("VM02_C27_RIVAL_CANONICAL_READY=" + $(if ($rivalCanonicalReady) { "PASS" } else { "BLOCKED" }))
Write-Host ("VM02_C27_ARENA_CANONICAL_READY=" + $(if ($arenaCanonicalReady) { "PASS" } else { "BLOCKED" }))

$runtimeReady = (Test-Path (Join-Path $RepoRoot "scripts\runtime\first_playable_round_match_runtime.gd")) -and (Test-Path (Join-Path $RepoRoot "scenes\runtime\first_playable_round_match_runtime.tscn"))
Write-Host ("VM02_C27_C26_RUNTIME_BASELINE=" + $(if ($runtimeReady) { "PASS" } else { "BLOCKED" }))

$blockers = New-Object System.Collections.Generic.List[string]
if (-not $lianPresent) { $blockers.Add("lian_canonical_root_missing") }
if (-not $rivalCanonicalReady) { $blockers.Add("second_canonical_fighter_pack_missing") }
if (-not $arenaCanonicalReady) { $blockers.Add("canonical_v2_arena_missing") }
if ($contract.presentation.required.combat_sfx) { $blockers.Add("combat_sfx_not_yet_validated") }
if ($contract.presentation.required.music) { $blockers.Add("music_not_yet_validated") }

$blockerCount = $blockers.Count
Write-Host "VM02_C27_V2_BLOCKER_COUNT=$blockerCount"
foreach ($blocker in $blockers) { Write-Host "VM02_C27_V2_BLOCKER=$blocker" }

$pipelineReady = $runtimeReady -and $contract.definition_of_done.no_mirrored_character_proxy -and $contract.definition_of_done.no_prototype_stage
if (-not $pipelineReady) { throw "VM02_C27_PIPELINE_READY=BLOCKED" }
Write-Host "VM02_C27_PIPELINE_READY=PASS"

$v2ContentReady = $lianPresent -and $rivalCanonicalReady -and $arenaCanonicalReady -and $blockerCount -eq 0
Write-Host ("VM02_C27_V2_CONTENT_READY=" + $(if ($v2ContentReady) { "PASS" } else { "BLOCKED" }))
Write-Host "VM02_C27_PREFLIGHT_GATE=PASS"

. $reportLib
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C27-V2-CONTENT-PREFLIGHT" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  CONTRACT_SCHEMA="PASS"
  C26_RUNTIME_BASELINE=$(if ($runtimeReady) { "PASS" } else { "BLOCKED" })
  LIAN_CANONICAL_ROOT=$(if ($lianPresent) { "PASS" } else { "BLOCKED" })
  RIVAL_CANONICAL_READY=$(if ($rivalCanonicalReady) { "PASS" } else { "BLOCKED" })
  ARENA_CANONICAL_READY=$(if ($arenaCanonicalReady) { "PASS" } else { "BLOCKED" })
  V2_CONTENT_READY=$(if ($v2ContentReady) { "PASS" } else { "BLOCKED" })
  BLOCKER_COUNT=$blockerCount
  BLOCKERS=($blockers -join ',')
}) -CopyToClipboard
