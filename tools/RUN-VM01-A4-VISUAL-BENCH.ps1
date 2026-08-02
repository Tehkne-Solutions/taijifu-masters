param(
  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = ".",
  [Parameter(Mandatory=$false)]
  [string]$GodotExe = ""
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

$godot = Resolve-GodotExecutable -Explicit $GodotExe
if (-not $godot) {
  Write-Host "VM01_A4_GODOT_RESOLVE=BLOCKED"
  exit 2
}

Write-Host "VM01_A4_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$artifactDir = Join-Path $RepoRoot "artifacts\vm01-a4"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$output = Join-Path $artifactDir "lian-wu-character-lock-bench-1920x1080.png"
if (Test-Path $output) { Remove-Item $output -Force }

$logDir = Join-Path $RepoRoot ".godot\vm01-a4"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir "visual-bench.stdout.log"
$stderr = Join-Path $logDir "visual-bench.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue

$args = @(
  "--path", $RepoRoot,
  "--resolution", "1920x1080",
  "res://scenes/visual/lian_wu_character_lock_visual_bench.tscn",
  "--",
  "--capture-and-quit"
)

$process = Start-Process -FilePath $godot -ArgumentList $args -WorkingDirectory $RepoRoot -Wait -PassThru `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr

$combined = @()
if (Test-Path $stdout) { $combined += Get-Content $stdout }
if (Test-Path $stderr) { $combined += Get-Content $stderr }
foreach ($line in $combined) { Write-Host $line }

$fatal = $combined | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|VM01_A4_VISUAL_BENCH_RUNTIME=BLOCKED" }
if ($process.ExitCode -ne 0 -or $fatal.Count -gt 0 -or -not (Test-Path $output)) {
  Write-Host "VM01_A4_VISUAL_BENCH=BLOCKED"
  Write-Host "STDOUT=$stdout"
  Write-Host "STDERR=$stderr"
  exit 3
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($output)
try {
  if ($image.Width -ne 1920 -or $image.Height -ne 1080) {
    Write-Host "VM01_A4_VISUAL_BENCH=BLOCKED_SIZE"
    exit 4
  }
} finally {
  $image.Dispose()
}

$hash = (Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
Write-Host "VM01_A4_VISUAL_BENCH=PASS"
Write-Host "VM01_A4_VISUAL_BENCH_OUTPUT=$output"
Write-Host "VM01_A4_VISUAL_BENCH_SHA256=$hash"
