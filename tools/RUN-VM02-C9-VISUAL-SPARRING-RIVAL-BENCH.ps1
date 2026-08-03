param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/opponent_visual_sparring_rival.gd",
  "scripts/runtime/opponent_visual_sparring_rival_bench.gd",
  "scenes/runtime/opponent_visual_sparring_rival_bench.tscn"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C9_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C9_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C9_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C9_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c9"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$bootOut = Join-Path $logDir "bootstrap.stdout.log"
$bootErr = Join-Path $logDir "bootstrap.stderr.log"
$stdout = Join-Path $logDir "visual-rival.stdout.log"
$stderr = Join-Path $logDir "visual-rival.stderr.log"

$boot = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--editor","--headless","--quit-after","3") -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -WindowStyle Hidden
$boot.WaitForExit()
Write-Host "VM02_C9_GODOT_BOOTSTRAP=PASS"

$run = Start-Process -FilePath $godotExe -ArgumentList @("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/opponent_visual_sparring_rival_bench.tscn","--","--capture-and-quit") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $run.WaitForExit(15000)) {
  try { $run.Kill() } catch {}
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C9_VISUAL_RIVAL_BENCH=BLOCKED timeout"
}
$run.WaitForExit(); $run.Refresh()
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
$markers = @(
  "VM02_C9_STATE_SET=PASS",
  "VM02_C9_GEOMETRIC_PLACEHOLDER=OFF",
  "VM02_C9_MIRRORED_FACING=PASS",
  "VM02_C9_PALETTE_VARIANT=PASS",
  "VM02_C9_VISUAL_RUNTIME=PASS",
  "VM02_C9_CAPTURE=PASS"
)
foreach ($marker in $markers) { if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C9_VISUAL_RIVAL_BENCH=BLOCKED missing_marker=$marker" } }
if ($text -match "SCRIPT ERROR|Parse Error|Failed to load script") { throw "VM02_C9_VISUAL_RIVAL_BENCH=BLOCKED fatal_runtime_error" }

$output = Join-Path $RepoRoot "artifacts\vm02-c9\visual-sparring-rival-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C9_VISUAL_RIVAL_BENCH=BLOCKED missing_capture" }
Write-Host "VM02_C9_VISUAL_RIVAL_BENCH=PASS"
Write-Host "VM02_C9_VISUAL_RIVAL_BENCH_OUTPUT=$output"
Write-Host "VM02_C9_VISUAL_RIVAL_BENCH_SHA256=$((Get-FileHash $output -Algorithm SHA256).Hash.ToLower())"
Write-Host "VM02_C9_REVIEW=PENDING_VISUAL_REVIEW"
