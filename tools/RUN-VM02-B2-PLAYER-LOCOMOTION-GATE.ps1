param(
  [Parameter(Mandatory=$false)][string]$RepoRoot = ".",
  [Parameter(Mandatory=$false)][string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

function Resolve-GodotExecutable {
  param([string]$Explicit)
  if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
    if (Test-Path $Explicit) { return (Resolve-Path $Explicit).Path }
    throw "Godot executable not found at explicit path: $Explicit"
  }
  foreach ($cmdName in @("godot", "godot4", "godot.exe", "godot4.exe")) {
    $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
  }
  $roots = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
    "$env:LOCALAPPDATA\Programs",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}",
    "C:\Godot",
    "C:\tools"
  ) | Where-Object { $_ -and (Test-Path $_) }
  foreach ($root in $roots) {
    $found = Get-ChildItem -Path $root -File -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notmatch "console" } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($found) { return $found.FullName }
  }
  return $null
}

$required = @(
  "scripts\runtime\lian_wu_player_locomotion_controller.gd",
  "scripts\runtime\lian_wu_player_locomotion_gate.gd",
  "scenes\runtime\lian_wu_player_locomotion_gate.tscn"
)
foreach ($relative in $required) {
  if (-not (Test-Path (Join-Path $RepoRoot $relative))) {
    Write-Host "VM02_B2_REQUIRED_FILES=BLOCKED missing=$relative"
    exit 2
  }
}
Write-Host "VM02_B2_REQUIRED_FILES=PASS"

$godot = Resolve-GodotExecutable -Explicit $GodotExe
if (-not $godot) { Write-Host "VM02_B2_GODOT_RESOLVE=BLOCKED"; exit 3 }
Write-Host "VM02_B2_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$artifactDir = Join-Path $RepoRoot "artifacts\vm02-b2"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$output = Join-Path $artifactDir "lian-wu-player-controlled-1920x1080.png"
if (Test-Path $output) { Remove-Item $output -Force }

$logDir = Join-Path $RepoRoot ".godot\vm02-b2"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir "player-locomotion.stdout.log"
$stderr = Join-Path $logDir "player-locomotion.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue

$args = @(
  "--path", $RepoRoot,
  "--resolution", "1920x1080",
  "res://scenes/runtime/lian_wu_player_locomotion_gate.tscn",
  "--",
  "--autoplay",
  "--capture-and-quit"
)

$process = Start-Process -FilePath $godot -ArgumentList $args -WorkingDirectory $RepoRoot -Wait -PassThru `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr

$combined = @()
if (Test-Path $stdout) { $combined += Get-Content $stdout }
if (Test-Path $stderr) { $combined += Get-Content $stderr }
foreach ($line in $combined) { Write-Host $line }

$fatal = @($combined | Where-Object {
  $_ -match "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|VM02_B2_PLAYER_CONTROL_RUNTIME=BLOCKED"
})
$requiredPass = @(
  "VM02_B2_LOCOMOTION_FRAME_TOTAL=36",
  "VM02_B2_PLAYER_CONTROL_RUNTIME=PASS",
  "VM02_B2_WALK=PASS",
  "VM02_B2_RUN=PASS",
  "VM02_B2_JUMP_CHAIN=PASS",
  "VM02_B2_FACING_FLIP=PASS",
  "VM02_B2_CAPTURE=PASS"
)
foreach ($marker in $requiredPass) {
  if (-not ($combined -contains $marker)) {
    Write-Host "VM02_B2_PLAYER_LOCOMOTION_GATE=BLOCKED missing_marker=$marker"
    Write-Host "STDOUT=$stdout"
    Write-Host "STDERR=$stderr"
    exit 4
  }
}
if ($process.ExitCode -ne 0 -or $fatal.Count -gt 0 -or -not (Test-Path $output)) {
  Write-Host "VM02_B2_PLAYER_LOCOMOTION_GATE=BLOCKED"
  Write-Host "STDOUT=$stdout"
  Write-Host "STDERR=$stderr"
  exit 5
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($output)
try {
  if ($image.Width -ne 1920 -or $image.Height -ne 1080) {
    Write-Host "VM02_B2_PLAYER_LOCOMOTION_GATE=BLOCKED_SIZE"
    exit 6
  }
} finally { $image.Dispose() }

$hash = (Get-FileHash $output -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_B2_PLAYER_LOCOMOTION_GATE=PASS"
Write-Host "VM02_B2_PLAYER_LOCOMOTION_GATE_OUTPUT=$output"
Write-Host "VM02_B2_PLAYER_LOCOMOTION_GATE_SHA256=$hash"
Write-Host "VM02_B2_PLAYER_REVIEW=PENDING_VISUAL_REVIEW"
