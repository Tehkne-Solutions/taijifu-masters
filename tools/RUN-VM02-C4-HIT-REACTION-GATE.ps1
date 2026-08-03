param([string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "scripts/runtime/lian_wu_hit_reaction_gate.gd",
  "scripts/runtime/lian_wu_reactive_combat_dummy.gd",
  "scenes/runtime/lian_wu_hit_reaction_gate.tscn"
)
foreach ($file in $required) { if (-not (Test-Path $file)) { throw "VM02_C4_REQUIRED_FILES=BLOCKED missing=$file" } }
Write-Host "VM02_C4_REQUIRED_FILES=PASS"

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) { $godot = Get-Command godot4 -ErrorAction SilentlyContinue }
if (-not $godot) {
  $candidate = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $godotExe = $candidate.FullName } else { throw "VM02_C4_GODOT_RESOLVE=BLOCKED" }
} else { $godotExe = $godot.Source }
Write-Host "VM02_C4_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir = Join-Path $RepoRoot ".godot\vm02-c4"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir "hit-reaction.stdout.log"
$stderr = Join-Path $logDir "hit-reaction.stderr.log"
$bootstrapStdout = Join-Path $logDir "bootstrap.stdout.log"
$bootstrapStderr = Join-Path $logDir "bootstrap.stderr.log"
Remove-Item $stdout,$stderr,$bootstrapStdout,$bootstrapStderr -Force -ErrorAction SilentlyContinue

# Warm project import/cache. Benign stderr warnings must not abort PowerShell.
$bootstrap = Start-Process -FilePath $godotExe -ArgumentList @("--path", $RepoRoot, "--editor", "--headless", "--quit-after", "3") -WorkingDirectory $RepoRoot -Wait -PassThru -RedirectStandardOutput $bootstrapStdout -RedirectStandardError $bootstrapStderr
if ($bootstrap.ExitCode -ne 0) {
  Write-Host "VM02_C4_GODOT_BOOTSTRAP=BLOCKED exit=$($bootstrap.ExitCode)"
  if (Test-Path $bootstrapStdout) { Get-Content $bootstrapStdout }
  if (Test-Path $bootstrapStderr) { Get-Content $bootstrapStderr }
  exit 3
}
Write-Host "VM02_C4_GODOT_BOOTSTRAP=PASS"

# Important: capture runtime must use a rendered viewport, matching the proven C3 runner.
$args = @(
  "--path", $RepoRoot,
  "--resolution", "1920x1080",
  "res://scenes/runtime/lian_wu_hit_reaction_gate.tscn",
  "--",
  "--capture-and-quit"
)
$run = Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$timeoutSeconds = 15
if (-not $run.WaitForExit($timeoutSeconds * 1000)) {
  try { $run.Kill() } catch {}
  Write-Host "VM02_C4_PROCESS_TIMEOUT=BLOCKED seconds=$timeoutSeconds"
  if (Test-Path $stdout) { Get-Content $stdout }
  if (Test-Path $stderr) { Get-Content $stderr }
  throw "VM02_C4_HIT_REACTION_GATE=BLOCKED process_timeout"
}

# PowerShell/.NET can leave ExitCode unmaterialized after the timed WaitForExit overload.
# Complete the wait and refresh the process object before reading ExitCode.
$run.WaitForExit()
$run.Refresh()
$exitCode = $run.ExitCode
Write-Host "VM02_C4_GODOT_RUNTIME_EXIT=$exitCode"

if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }
if ($exitCode -ne 0) { throw "VM02_C4_HIT_REACTION_GATE=BLOCKED godot_exit=$exitCode" }

$markers = @(
  "VM02_C4_HIT_REACTION=PASS",
  "VM02_C4_HITSTUN=PASS",
  "VM02_C4_KNOCKBACK=PASS",
  "VM02_C4_RECOVERY=PASS",
  "VM02_C4_RETURN_IDLE=PASS",
  "VM02_C4_RUNTIME=PASS",
  "VM02_C4_CAPTURE=PASS"
)
$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
foreach ($marker in $markers) {
  if ($text -notmatch [regex]::Escape($marker)) {
    throw "VM02_C4_HIT_REACTION_GATE=BLOCKED missing_marker=$marker"
  }
}
$output = Join-Path $RepoRoot "artifacts\vm02-c4\lian-wu-hit-reaction-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C4_HIT_REACTION_GATE=BLOCKED missing_capture" }
Write-Host "VM02_C4_HIT_REACTION_GATE=PASS"
Write-Host "VM02_C4_HIT_REACTION_GATE_OUTPUT=$output"
Write-Host "VM02_C4_HIT_REACTION_GATE_SHA256=$((Get-FileHash $output -Algorithm SHA256).Hash.ToLower())"
Write-Host "VM02_C4_REVIEW=PENDING_VISUAL_REVIEW"
