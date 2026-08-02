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
  "assets\pack_01_characters\lian_wu\frames\idle\char_lian_wu__idle__f01.png",
  "assets\pack_01_characters\lian_wu\frames\walk\char_lian_wu__walk__f01.png",
  "assets\pack_01_characters\lian_wu\frames\run\char_lian_wu__run__f01.png",
  "assets\pack_01_characters\lian_wu\frames\jump_start\char_lian_wu__jump_start__f01.png",
  "assets\pack_01_characters\lian_wu\frames\jump_loop\char_lian_wu__jump_loop__f01.png",
  "assets\pack_01_characters\lian_wu\frames\fall\char_lian_wu__fall__f01.png",
  "assets\pack_01_characters\lian_wu\frames\land\char_lian_wu__land__f01.png"
)
foreach ($relative in $required) {
  if (-not (Test-Path (Join-Path $RepoRoot $relative))) {
    Write-Host "VM02_B1_LOCOMOTION_RUNTIME=BLOCKED_REQUIRED_ASSET_MISSING $relative"
    exit 2
  }
}
Write-Host "VM02_B1_REQUIRED_ASSET_FAMILIES=PASS"

$godot = Resolve-GodotExecutable -Explicit $GodotExe
if (-not $godot) { Write-Host "VM02_B1_GODOT_RESOLVE=BLOCKED"; exit 3 }
Write-Host "VM02_B1_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$artifactDir = Join-Path $RepoRoot "artifacts\vm02-b1"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$output = Join-Path $artifactDir "lian-wu-integrated-locomotion-1920x1080.png"
if (Test-Path $output) { Remove-Item $output -Force }

$logDir = Join-Path $RepoRoot ".godot\vm02-b1"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir "integrated-locomotion.stdout.log"
$stderr = Join-Path $logDir "integrated-locomotion.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue

$args = @(
  "--path", $RepoRoot,
  "--resolution", "1920x1080",
  "res://scenes/runtime/lian_wu_locomotion_runtime_gate.tscn",
  "--",
  "--capture-and-quit"
)

$process = Start-Process -FilePath $godot -ArgumentList $args -WorkingDirectory $RepoRoot -Wait -PassThru `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$combined = @()
if (Test-Path $stdout) { $combined += Get-Content $stdout }
if (Test-Path $stderr) { $combined += Get-Content $stderr }
foreach ($line in $combined) { Write-Host $line }

$fatal = @($combined | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|VM02_B1_LOCOMOTION_RUNTIME=BLOCKED" })
$runtimePass = @($combined | Where-Object { $_ -match "VM02_B1_LOCOMOTION_RUNTIME=PASS" }).Count -gt 0
$statePass = @($combined | Where-Object { $_ -match "VM02_B1_STATE_ORDER=PASS" }).Count -gt 0
$landingPass = @($combined | Where-Object { $_ -match "VM02_B1_LANDING=PASS" }).Count -gt 0
$assetPass = @($combined | Where-Object { $_ -match "VM02_B1_LOCOMOTION_FRAME_TOTAL=36" }).Count -gt 0

if ($process.ExitCode -ne 0 -or $fatal.Count -gt 0 -or -not $runtimePass -or -not $statePass -or -not $landingPass -or -not $assetPass -or -not (Test-Path $output)) {
  Write-Host "VM02_B1_LOCOMOTION_RUNTIME_GATE=BLOCKED"
  Write-Host "STDOUT=$stdout"
  Write-Host "STDERR=$stderr"
  exit 4
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($output)
try {
  if ($image.Width -ne 1920 -or $image.Height -ne 1080) {
    Write-Host "VM02_B1_LOCOMOTION_RUNTIME_GATE=BLOCKED_SIZE"
    exit 5
  }
} finally { $image.Dispose() }

$hash = (Get-FileHash $output -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_B1_LOCOMOTION_RUNTIME_GATE=PASS"
Write-Host "VM02_B1_LOCOMOTION_RUNTIME_GATE_OUTPUT=$output"
Write-Host "VM02_B1_LOCOMOTION_RUNTIME_GATE_SHA256=$hash"
Write-Host "VM02_B1_INTEGRATED_REVIEW=PENDING_VISUAL_REVIEW"
