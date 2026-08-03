param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_defense_stamina.gd",
  "scenes/runtime/first_playable_defense_stamina.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C15_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C15_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C15_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C15_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c15"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "defense-stamina.stdout.log"
$stderr = Join-Path $logDir "defense-stamina.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C15_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_defense_stamina.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(35000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C15_DEFENSE_STAMINA_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C15_DEFENSE_STAMINA_READY=PASS",
  "VM02_C15_BLOCK_DAMAGE_REDUCTION=PASS",
  "VM02_C15_BLOCK_KNOCKBACK_REDUCTION=PASS",
  "VM02_C15_STAMINA_SPEND=PASS",
  "VM02_C15_STAMINA_REGEN=PASS",
  "VM02_C15_NORMAL_DAMAGE_PATH=PASS",
  "VM02_C15_BLOCK_EVIDENCE_COVERAGE=PASS",
  "VM02_C15_RUNTIME=PASS",
  "VM02_C14_RUNTIME=PASS",
  "VM02_C13_RUNTIME=PASS",
  "VM02_C15_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C15_DEFENSE_STAMINA_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C15_DEFENSE_STAMINA_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c15\first-playable-defense-stamina-1920x1080.png"
$blockOutput = Join-Path $RepoRoot "artifacts\vm02-c15\block-evidence-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C15_DEFENSE_STAMINA_GATE=BLOCKED missing_final_capture" }
if (-not (Test-Path $blockOutput)) { throw "VM02_C15_DEFENSE_STAMINA_GATE=BLOCKED missing_block_capture" }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$blockSha = (Get-FileHash $blockOutput -Algorithm SHA256).Hash.ToLower()
if ($sha -eq $blockSha) { throw "VM02_C15_DEFENSE_STAMINA_GATE=BLOCKED block_capture_equals_final" }
Write-Host "VM02_C15_BLOCK_EVIDENCE_FILE=PASS"
Write-Host "VM02_C15_BLOCK_EVIDENCE_SHA256=$blockSha"
Write-Host "VM02_C15_DEFENSE_STAMINA_GATE=PASS"
Write-Host "VM02_C15_DEFENSE_STAMINA_GATE_OUTPUT=$output"
Write-Host "VM02_C15_DEFENSE_STAMINA_GATE_SHA256=$sha"
Write-Host "VM02_C15_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C15-DEFENSE-STAMINA-FOUNDATION" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  BLOCK_DAMAGE_REDUCTION="PASS"
  BLOCK_KNOCKBACK_REDUCTION="PASS"
  STAMINA_SPEND="PASS"
  STAMINA_REGEN="PASS"
  NORMAL_DAMAGE_PATH="PASS"
  BLOCK_EVIDENCE="PASS"
  C14_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  BLOCK_ARTIFACT=$blockOutput
  BLOCK_SHA256=$blockSha
}) -CopyToClipboard
