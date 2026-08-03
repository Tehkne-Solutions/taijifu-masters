param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "tools/generate_lian_wu_riposte6.py",
  "scripts/runtime/lian_wu_riposte_visual_controller.gd",
  "scripts/runtime/first_playable_riposte_visual_polish.gd",
  "scenes/runtime/first_playable_riposte_visual_polish.tscn",
  "tools/lib/Write-TehkneGateReport.ps1"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C20_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C20_REQUIRED_FILES=PASS"

$python = Get-Command py -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) { throw "VM02_C20_PYTHON_RESOLVE=BLOCKED" }
Write-Host "VM02_C20_PYTHON_RESOLVE=PASS"
& $python.Source -c "import PIL; print('VM02_C20_PILLOW=PASS'); print('PILLOW_VERSION=' + PIL.__version__)"
if ($LASTEXITCODE -ne 0) { throw "VM02_C20_PILLOW=BLOCKED" }
& $python.Source (Join-Path $RepoRoot "tools\generate_lian_wu_riposte6.py") --repo-root $RepoRoot
if ($LASTEXITCODE -ne 0) { throw "VM02_C20_RIPOSTE6=BLOCKED_GENERATION" }

$frames = Get-ChildItem (Join-Path $RepoRoot "assets\pack_01_characters\lian_wu\frames\attacks\ji_riposte\char_lian_wu__ji_riposte__f*.png") -ErrorAction SilentlyContinue
if (@($frames).Count -ne 6) { throw "VM02_C20_RIPOSTE_FRAMES=BLOCKED count=$(@($frames).Count)" }
Write-Host "VM02_C20_RIPOSTE_FRAMES=PASS count=6"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C20_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C20_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c20"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "riposte-visual.stdout.log"
$stderr = Join-Path $logDir "riposte-visual.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C20_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/first_playable_riposte_visual_polish.tscn","--","--capture-and-quit","--autoplay") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(55000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C20_GATE=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C20_READY=PASS",
  "VM02_C20_RIPOSTE_VISUAL_READY=PASS",
  "VM02_C20_RIPOSTE_RUNTIME_BINDING=PASS",
  "VM02_C20_RIPOSTE_VISUAL_BINDING=PASS",
  "VM02_C20_HUD_CLEANUP=PASS",
  "VM02_C20_HUD_COLLISION_FREE=PASS",
  "VM02_C20_RIPOSTE_VISUAL_EVIDENCE_COVERAGE=PASS",
  "VM02_C20_C19_CONTRACT=PASS",
  "VM02_C20_RUNTIME=PASS",
  "VM02_C19_RUNTIME=PASS",
  "VM02_C18_RUNTIME=PASS",
  "VM02_C17_RUNTIME=PASS",
  "VM02_C20_CAPTURE=PASS"
)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C20_GATE=BLOCKED missing_marker=$marker" }
}
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C20_GATE=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c20\first-playable-riposte-visual-polish-1920x1080.png"
$riposteOutput = Join-Path $RepoRoot "artifacts\vm02-c20\riposte-visual-evidence-1920x1080.png"
foreach ($file in @($output,$riposteOutput)) { if (-not (Test-Path $file)) { throw "VM02_C20_GATE=BLOCKED missing_artifact=$file" } }
$sha = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
$riposteSha = (Get-FileHash $riposteOutput -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C20_EVIDENCE_FILES=PASS"
Write-Host "VM02_C20_RIPOSTE_VISUAL_HUD_GATE=PASS"
Write-Host "VM02_C20_RIPOSTE_VISUAL_HUD_GATE_OUTPUT=$output"
Write-Host "VM02_C20_RIPOSTE_VISUAL_HUD_GATE_SHA256=$sha"
Write-Host "VM02_C20_REVIEW=PENDING_VISUAL_REVIEW"

. (Join-Path $RepoRoot "tools\lib\Write-TehkneGateReport.ps1")
$branch = (git branch --show-current).Trim()
$commit = (git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C20-RIPOSTE-VISUAL-HUD" -Status "PASS" -Branch $branch -Commit $commit -Values ([ordered]@{
  RIPOSTE_KEYPOSES="PASS"
  RIPOSTE_VISUAL_BINDING="PASS"
  HUD_CLEANUP="PASS"
  HUD_COLLISION_FREE="PASS"
  RIPOSTE_VISUAL_EVIDENCE="PASS"
  C19_CONTRACT="PASS"
  RUNTIME="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  RIPOSTE_ARTIFACT=$riposteOutput
  RIPOSTE_SHA256=$riposteSha
}) -CopyToClipboard
