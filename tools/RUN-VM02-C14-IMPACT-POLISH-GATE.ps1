param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_impact_polish.gd",
  "scenes/runtime/first_playable_impact_polish.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C14_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C14_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C14_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C14_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c14"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "impact-polish.stdout.log"
$stderr = Join-Path $logDir "impact-polish.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C14_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_impact_polish.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(30000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C14_IMPACT_POLISH_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C14_IMPACT_POLISH_READY=PASS",
  "VM02_C14_CONTACT_CORE_COVERAGE=PASS",
  "VM02_C14_REACTION_READABILITY=PASS",
  "VM02_C14_TECHNIQUE_CONTRAST=PASS",
  "VM02_C14_IMPACT_EVIDENCE_COVERAGE=PASS",
  "VM02_C14_C13_CONTRACT=PASS",
  "VM02_C14_RUNTIME=PASS",
  "VM02_C13_RUNTIME=PASS",
  "VM02_C14_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C14_IMPACT_POLISH_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C14_IMPACT_POLISH_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c14\first-playable-impact-polish-1920x1080.png"
$impactOutput = Join-Path $RepoRoot "artifacts\vm02-c14\impact-readability-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C14_IMPACT_POLISH_GATE=BLOCKED missing_final_capture" }
if (-not (Test-Path $impactOutput)) { throw "VM02_C14_IMPACT_POLISH_GATE=BLOCKED missing_impact_capture" }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$impactSha = (Get-FileHash $impactOutput -Algorithm SHA256).Hash.ToLower()
if ($sha -eq $impactSha) { throw "VM02_C14_IMPACT_POLISH_GATE=BLOCKED impact_capture_equals_final" }
Write-Host "VM02_C14_IMPACT_EVIDENCE_FILE=PASS"
Write-Host "VM02_C14_IMPACT_EVIDENCE_SHA256=$impactSha"
Write-Host "VM02_C14_IMPACT_POLISH_GATE=PASS"
Write-Host "VM02_C14_IMPACT_POLISH_GATE_OUTPUT=$output"
Write-Host "VM02_C14_IMPACT_POLISH_GATE_SHA256=$sha"
Write-Host "VM02_C14_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C14-IMPACT-READABILITY-REACTION-POLISH" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  CONTACT_CORE="PASS"
  REACTION_READABILITY="PASS"
  TECHNIQUE_CONTRAST="PASS"
  IMPACT_EVIDENCE="PASS"
  C13_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  IMPACT_ARTIFACT=$impactOutput
  IMPACT_SHA256=$impactSha
}) -CopyToClipboard
