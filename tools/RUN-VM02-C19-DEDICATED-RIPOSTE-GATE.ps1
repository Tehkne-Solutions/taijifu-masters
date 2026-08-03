param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/first_playable_dedicated_riposte.gd",
  "scenes/runtime/first_playable_dedicated_riposte.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C19_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C19_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C19_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C19_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c19"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "dedicated-riposte.stdout.log"
$stderr = Join-Path $logDir "dedicated-riposte.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C19_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_dedicated_riposte.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(50000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C19_DEDICATED_RIPOSTE_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C19_DEDICATED_RIPOSTE_READY=PASS",
  "VM02_C19_RIPOSTE_ARM=PASS",
  "VM02_C19_RIPOSTE_BINDING=PASS",
  "VM02_C19_RIPOSTE_DAMAGE=PASS",
  "VM02_C19_RIPOSTE_STAMINA=PASS",
  "VM02_C19_RIPOSTE_GUARD_PRESSURE=PASS",
  "VM02_C19_RIPOSTE_SINGLE_CONSUME=PASS",
  "VM02_C19_RIPOSTE_EVIDENCE_COVERAGE=PASS",
  "VM02_C19_C18_CONTRACT=PASS",
  "VM02_C19_RUNTIME=PASS",
  "VM02_C18_RUNTIME=PASS",
  "VM02_C17_RUNTIME=PASS",
  "VM02_C19_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C19_DEDICATED_RIPOSTE_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C19_DEDICATED_RIPOSTE_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c19\first-playable-dedicated-riposte-1920x1080.png"
$riposteOutput = Join-Path $RepoRoot "artifacts\vm02-c19\riposte-evidence-1920x1080.png"
foreach ($file in @($output,$riposteOutput)) { if (-not (Test-Path $file)) { throw "VM02_C19_DEDICATED_RIPOSTE_GATE=BLOCKED missing_artifact=$file" } }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$riposteSha = (Get-FileHash $riposteOutput -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C19_EVIDENCE_FILES=PASS"
Write-Host "VM02_C19_DEDICATED_RIPOSTE_GATE=PASS"
Write-Host "VM02_C19_DEDICATED_RIPOSTE_GATE_OUTPUT=$output"
Write-Host "VM02_C19_DEDICATED_RIPOSTE_GATE_SHA256=$sha"
Write-Host "VM02_C19_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C19-DEDICATED-RIPOSTE-TECHNIQUE" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  RIPOSTE_ARM="PASS"
  RIPOSTE_BINDING="PASS"
  RIPOSTE_DAMAGE="PASS"
  RIPOSTE_STAMINA="PASS"
  RIPOSTE_GUARD_PRESSURE="PASS"
  RIPOSTE_SINGLE_CONSUME="PASS"
  RIPOSTE_EVIDENCE="PASS"
  C18_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  RIPOSTE_ARTIFACT=$riposteOutput
  RIPOSTE_SHA256=$riposteSha
}) -CopyToClipboard
