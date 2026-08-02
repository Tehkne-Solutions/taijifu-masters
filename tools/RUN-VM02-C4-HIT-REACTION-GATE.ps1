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
& $godotExe --path $RepoRoot --editor --headless --quit-after 3 2>&1 | Out-Null
& $godotExe --path $RepoRoot --headless "res://scenes/runtime/lian_wu_hit_reaction_gate.tscn" -- --capture-and-quit 1>$stdout 2>$stderr
Get-Content $stdout
if (Test-Path $stderr) { Get-Content $stderr }

$markers = @("VM02_C4_HIT_REACTION=PASS","VM02_C4_HITSTUN=PASS","VM02_C4_KNOCKBACK=PASS","VM02_C4_RECOVERY=PASS","VM02_C4_RETURN_IDLE=PASS","VM02_C4_RUNTIME=PASS","VM02_C4_CAPTURE=PASS")
$text = (Get-Content $stdout -Raw) + "`n" + (Get-Content $stderr -Raw)
foreach ($marker in $markers) { if ($text -notmatch [regex]::Escape($marker)) { throw "VM02_C4_HIT_REACTION_GATE=BLOCKED missing_marker=$marker" } }
$output = Join-Path $RepoRoot "artifacts\vm02-c4\lian-wu-hit-reaction-1920x1080.png"
if (-not (Test-Path $output)) { throw "VM02_C4_HIT_REACTION_GATE=BLOCKED missing_capture" }
Write-Host "VM02_C4_HIT_REACTION_GATE=PASS"
Write-Host "VM02_C4_HIT_REACTION_GATE_OUTPUT=$output"
Write-Host "VM02_C4_HIT_REACTION_GATE_SHA256=$((Get-FileHash $output -Algorithm SHA256).Hash.ToLower())"
Write-Host "VM02_C4_REVIEW=PENDING_VISUAL_REVIEW"
