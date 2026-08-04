param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$progressPath = Join-Path $RepoRoot "config\v2-production-progress.json"
if (-not (Test-Path $progressPath)) { throw "VM02_C43_REQUIRED_FILES=BLOCKED progress_missing" }
Write-Host "VM02_C43_REQUIRED_FILES=PASS"

$progress = Get-Content $progressPath -Raw | ConvertFrom-Json
if (-not [bool]$progress.v2_playable.runtime_ready) { throw "VM02_C43_RUNTIME_READY=BLOCKED" }
Write-Host "VM02_C43_RUNTIME_READY=PASS"

$workspace = Split-Path $RepoRoot -Parent
$c41Root = Join-Path $workspace "taijifu-masters-builds\vm02-c41"
if (-not (Test-Path $c41Root)) { throw "VM02_C43_C41_BUILD_ROOT=BLOCKED path=$c41Root" }

$zip = Get-ChildItem $c41Root -Filter "TAIJIFU_MASTERS_V2_PLAYTEST_*.zip" -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if (-not $zip) { throw "VM02_C43_PACKAGE=BLOCKED no_c41_zip" }
Write-Host "VM02_C43_PACKAGE=PASS path=$($zip.FullName)"
$sha = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C43_PACKAGE_SHA256=$sha"

$c43Root = Join-Path $workspace "taijifu-masters-builds\vm02-c43"
$sessionRoot = Join-Path $c43Root "current"
Remove-Item $sessionRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $sessionRoot | Out-Null
Expand-Archive -Path $zip.FullName -DestinationPath $sessionRoot -Force
Write-Host "VM02_C43_EXTRACT=PASS path=$sessionRoot"

$manifestPath = Join-Path $sessionRoot "PLAYTEST-MANIFEST.json"
if (-not (Test-Path $manifestPath)) { throw "VM02_C43_MANIFEST=BLOCKED missing" }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
if ($manifest.product -ne "Taijifu Masters" -or -not [bool]$manifest.runtime_ready) {
  throw "VM02_C43_MANIFEST=BLOCKED invalid_contract"
}
Write-Host "VM02_C43_MANIFEST=PASS"

$exe = Get-ChildItem (Join-Path $sessionRoot "windows") -Filter "*.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) { throw "VM02_C43_WINDOWS_BUILD=BLOCKED exe_missing" }
Write-Host "VM02_C43_WINDOWS_BUILD=PASS exe=$($exe.FullName)"

$launcher = Join-Path $c43Root "START-TAIJIFU-V2-PLAYTEST.cmd"
$launcherContent = @"
@echo off
setlocal
cd /d "$($exe.DirectoryName)"
start "Taijifu Masters V.2 Playtest" "$($exe.Name)"
echo.
echo Taijifu Masters V.2 Playtest iniciado.
echo Build: $($zip.Name)
echo Tehkne Solutions
"@
Set-Content -Path $launcher -Value $launcherContent -Encoding ASCII
Write-Host "VM02_C43_LAUNCHER=PASS path=$launcher"

$feedbackPath = Join-Path $c43Root "PLAYTEST-FEEDBACK.md"
$feedback = @"
# Taijifu Masters V.2 — Interactive Playtest Feedback

Build: `$($zip.Name)`  
SHA-256: `$sha`  
Signature: Tehkné Solutions

## Teste obrigatório
- [ ] Menu inicia sem travar
- [ ] Combate inicia
- [ ] Lian Wu responde aos controles
- [ ] Rival/IA entra em combate
- [ ] Mountain Dojo Night aparece corretamente
- [ ] Câmera acompanha a luta
- [ ] HUD permanece legível
- [ ] Ataque leve funciona
- [ ] Ataque pesado funciona
- [ ] Defesa/parry funciona
- [ ] Combos funcionam
- [ ] Knockdown/get-up funciona
- [ ] Round termina e reinicia corretamente
- [ ] Vitória/derrota funciona
- [ ] Sem erro fatal ou fechamento inesperado

## Revisão visual
- Player / Lian Wu:
- Rival provisório:
- Cenário:
- HUD:
- VFX:
- Câmera:

## Gameplay
- Movimento:
- Responsividade:
- IA:
- Combate:
- Dificuldade:
- Problemas encontrados:

## Decisão
- [ ] PLAYABLE_ACCEPTED
- [ ] PLAYABLE_WITH_FIXES
- [ ] BLOCKED
"@
Set-Content -Path $feedbackPath -Value $feedback -Encoding UTF8
Write-Host "VM02_C43_FEEDBACK_TEMPLATE=PASS path=$feedbackPath"

$handoffPath = Join-Path $c43Root "PLAYTEST-HANDOFF.json"
$handoff = [ordered]@{
  product = "Taijifu Masters"
  signature = "Tehkné Solutions"
  gate = "VM02-C43-V2-INTERACTIVE-PLAYTEST-HANDOFF"
  package = $zip.Name
  sha256 = $sha
  executable = $exe.FullName
  launcher = $launcher
  feedback = $feedbackPath
  runtime_ready = $true
  art_complete = $false
  training_rival_art = "isolated_pending"
  generated_at = (Get-Date).ToString("o")
}
$handoff | ConvertTo-Json -Depth 4 | Set-Content $handoffPath -Encoding UTF8
Write-Host "VM02_C43_HANDOFF=PASS path=$handoffPath"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C43-V2-INTERACTIVE-PLAYTEST-HANDOFF",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "RUNTIME_READY=PASS",
  "PACKAGE=PASS",
  "WINDOWS_BUILD=PASS",
  "LAUNCHER=PASS",
  "FEEDBACK_TEMPLATE=PASS",
  "HANDOFF=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=66%",
  "PROJECT_PROGRESS=49%",
  "LAUNCHER_PATH=$launcher",
  "FEEDBACK_PATH=$feedbackPath",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C43_V2_INTERACTIVE_PLAYTEST_HANDOFF_GATE=PASS"
Write-Host "Tehkne Solutions"
