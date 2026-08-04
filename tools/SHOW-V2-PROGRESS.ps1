param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$progressPath = Join-Path $RepoRoot "config\v2-production-progress.json"
if (-not (Test-Path $progressPath)) { throw "V2_PROGRESS=BLOCKED missing=$progressPath" }
$progress = Get-Content $progressPath -Raw | ConvertFrom-Json

$lines = @(
  "TAIJIFU_MASTERS_PROGRESS_BEGIN",
  "PHASE=$($progress.phase.id) $($progress.phase.name)",
  "PHASE_PROGRESS=$($progress.phase.progress_percent)%",
  "V2_PLAYABLE_PROGRESS=$($progress.v2_playable.progress_percent)%",
  "PROJECT_PROGRESS=$($progress.project.progress_percent)%",
  "RUNTIME_COMBAT_CORE=$($progress.v2_playable.runtime_combat_core)%",
  "ROUND_MATCH_LOOP=$($progress.v2_playable.round_match_loop)%",
  "CANONICAL_PLAYER=$($progress.v2_playable.canonical_player)%",
  "CANONICAL_SECOND_FIGHTER=$($progress.v2_playable.canonical_second_fighter)%",
  "CANONICAL_ARENA=$($progress.v2_playable.canonical_arena)%",
  "VFX_PRESENTATION=$($progress.v2_playable.vfx_presentation)%",
  "AUDIO=$($progress.v2_playable.audio)%",
  "PLAYTEST_PACKAGING=$($progress.v2_playable.playtest_packaging)%",
  "NEXT_PRIORITY=$($progress.next_priority[0])",
  "TAIJIFU_MASTERS_PROGRESS_END"
)
$lines | ForEach-Object { Write-Host $_ }
try {
  ($lines -join "`r`n") | Set-Clipboard
  Write-Host "TAIJIFU_MASTERS_PROGRESS_CLIPBOARD=PASS"
} catch {
  Write-Host "TAIJIFU_MASTERS_PROGRESS_CLIPBOARD=UNAVAILABLE"
}
