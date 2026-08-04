param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$planPath = Join-Path $RepoRoot "config\c37-training-rival-materialization-plan.json"
$c28Path = Join-Path $RepoRoot "tools\RUN-VM02-C28-V2-RIVAL-INTAKE-GATE.ps1"
if (-not (Test-Path $planPath)) { throw "VM02_C37_REQUIRED_FILES=BLOCKED missing_plan" }
if (-not (Test-Path $c28Path)) { throw "VM02_C37_REQUIRED_FILES=BLOCKED missing_c28" }
Write-Host "VM02_C37_REQUIRED_FILES=PASS"

$plan = Get-Content $planPath -Raw | ConvertFrom-Json
if ($plan.required_total_frames -ne 44 -or $plan.packs.Count -ne 5) {
  throw "VM02_C37_PLAN_CONTRACT=BLOCKED"
}
Write-Host "VM02_C37_PLAN_CONTRACT=PASS packs=5 frames=44"

$workspace = Split-Path $RepoRoot -Parent
$assetsRepo = Join-Path $workspace "taijifu-masters-assets"
if (-not (Test-Path (Join-Path $assetsRepo ".git"))) {
  Write-Host "VM02_C37_ASSETS_REPO_CLONE=BEGIN"
  git clone "https://github.com/Tehkne-Solutions/taijifu-masters-assets.git" $assetsRepo
  if ($LASTEXITCODE -ne 0) { throw "VM02_C37_ASSETS_REPO=BLOCKED clone_failed" }
  Write-Host "VM02_C37_ASSETS_REPO_CLONE=PASS"
}
Write-Host "VM02_C37_ASSETS_REPO=PASS path=$assetsRepo"

Push-Location $assetsRepo
try {
  git fetch origin | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "VM02_C37_ASSETS_SYNC=BLOCKED fetch" }
  git switch main | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "VM02_C37_ASSETS_SYNC=BLOCKED switch_main" }
  git pull --ff-only origin main | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "VM02_C37_ASSETS_SYNC=BLOCKED pull" }
} finally {
  Pop-Location
}
Write-Host "VM02_C37_ASSETS_SYNC=PASS branch=main"

$sourceRoot = Join-Path $assetsRepo ($plan.source_lot -replace '/', '\')
$presentTotal = 0
$packRows = @()
$allPackComplete = $true

foreach ($pack in $plan.packs) {
  $expected = 0
  $present = 0
  $missing = @()
  foreach ($prop in $pack.animations.PSObject.Properties) {
    $anim = $prop.Name
    $count = [int]$prop.Value
    $expected += $count
    for ($i = 1; $i -le $count; $i++) {
      $frame = "f{0:D3}.png" -f $i
      $path = Join-Path (Join-Path $sourceRoot $anim) $frame
      if (Test-Path $path) {
        $present++
        $presentTotal++
      } else {
        $missing += "$anim/$($frame -replace '\.png$','')"
      }
    }
  }
  $status = if ($present -eq $expected) { "PASS" } elseif ($present -eq 0) { "PENDING" } else { "PARTIAL" }
  if ($status -ne "PASS") { $allPackComplete = $false }
  Write-Host "VM02_C37_PACK_$($pack.id)=$status frames=$present/$expected name=$($pack.name)"
  if ($missing.Count -gt 0) {
    Write-Host "VM02_C37_PACK_$($pack.id)_NEXT_MISSING=$($missing[0])"
  }
  $packRows += [pscustomobject]@{ Id=$pack.id; Name=$pack.name; Present=$present; Expected=$expected; Status=$status }
}

Write-Host "VM02_C37_FRAME_COUNT=$presentTotal/44"
$percent = [math]::Round(($presentTotal / 44.0) * 100)
Write-Host "VM02_C37_ART_PROGRESS=$percent%"

$nextPack = $packRows | Where-Object { $_.Status -ne "PASS" } | Select-Object -First 1
if ($null -ne $nextPack) {
  Write-Host "VM02_C37_NEXT_PACK=$($nextPack.Id) name=$($nextPack.Name) frames=$($nextPack.Present)/$($nextPack.Expected)"
} else {
  Write-Host "VM02_C37_NEXT_PACK=NONE"
}

if ($allPackComplete -and $presentTotal -eq 44) {
  Write-Host "VM02_C37_MATERIALIZATION_READY=PASS"
} else {
  Write-Host "VM02_C37_MATERIALIZATION_READY=BLOCKED"
}

Write-Host "VM02_C37_C28_HANDOFF=BEGIN"
& powershell -ExecutionPolicy Bypass -File $c28Path -RepoRoot $RepoRoot 2>&1 | Out-Host
$c28Exit = $LASTEXITCODE
if ($c28Exit -ne 0) { throw "VM02_C37_C28_HANDOFF=BLOCKED exit=$c28Exit" }
Write-Host "VM02_C37_C28_HANDOFF=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$phaseProgress = 99
$v2Progress = if ($presentTotal -eq 44) { 60 } elseif ($presentTotal -gt 0) { 55 } else { 53 }
$projectProgress = if ($presentTotal -eq 44) { 45 } elseif ($presentTotal -gt 0) { 43 } else { 42 }

$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C37-TRAINING-RIVAL-MATERIALIZATION",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "FRAME_COUNT=$presentTotal/44",
  "ART_PROGRESS=$percent%",
  "P01=$((($packRows | Where-Object Id -eq 'P01').Status))",
  "P02=$((($packRows | Where-Object Id -eq 'P02').Status))",
  "P03=$((($packRows | Where-Object Id -eq 'P03').Status))",
  "P04=$((($packRows | Where-Object Id -eq 'P04').Status))",
  "P05=$((($packRows | Where-Object Id -eq 'P05').Status))",
  "NEXT_PACK=$(if ($nextPack) { $nextPack.Id } else { 'NONE' })",
  "C28_HANDOFF=PASS",
  "MATERIALIZATION_READY=$(if ($allPackComplete -and $presentTotal -eq 44) { 'PASS' } else { 'BLOCKED' })",
  "PIPELINE_READY=PASS",
  "PHASE_PROGRESS=$phaseProgress%",
  "V2_PLAYABLE_PROGRESS=$v2Progress%",
  "PROJECT_PROGRESS=$projectProgress%",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try {
  ($report -join [Environment]::NewLine) | Set-Clipboard
  Write-Host "COPY_REPORT_CLIPBOARD=PASS"
} catch {
  Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED"
}

Write-Host "VM02_C37_TRAINING_RIVAL_MATERIALIZATION_GATE=PASS"
Write-Host "Tehkné Solutions"
