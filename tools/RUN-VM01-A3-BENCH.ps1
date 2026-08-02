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

  $candidates = @()
  $roots = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:LOCALAPPDATA\Programs",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}",
    "C:\Godot",
    "C:\tools",
    "C:\ProgramData\chocolatey\bin",
    "$env:USERPROFILE\scoop\apps\godot\current"
  ) | Where-Object { $_ -and (Test-Path $_) }

  foreach ($root in $roots) {
    try {
      $found = Get-ChildItem -Path $root -File -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "console" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
      if ($found) { $candidates += $found.FullName }
    } catch {}
  }

  if ($candidates.Count -gt 0) { return $candidates[0] }
  return $null
}

$godot = Resolve-GodotExecutable -Explicit $GodotExe
if (-not $godot) {
  Write-Host "VM01_A3_GODOT_RESOLVE=BLOCKED"
  Write-Host "Godot executable was not found automatically."
  Write-Host "Install Godot 4.x or rerun with:"
  Write-Host '  .\tools\RUN-VM01-A3-BENCH.ps1 -RepoRoot "." -GodotExe "C:\path\Godot_v4.x-stable_win64.exe"'
  exit 2
}

Write-Host "VM01_A3_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

Push-Location $RepoRoot
try {
  Write-Host "VM01_A3_GODOT_BOOTSTRAP=RUNNING"
  & $godot --editor --headless --path . --quit
  $bootstrapExit = $LASTEXITCODE
  if ($bootstrapExit -ne 0) {
    Write-Host "VM01_A3_GODOT_BOOTSTRAP=BLOCKED"
    throw "VM01_A3_GODOT_BOOTSTRAP failed with exit code $bootstrapExit"
  }
  Write-Host "VM01_A3_GODOT_BOOTSTRAP=PASS"

  & $godot --headless --path . --script res://tests/lian_wu_character_lock_bench_contract.gd
  $contractExit = $LASTEXITCODE
  if ($contractExit -ne 0) {
    Write-Host "VM01_A3_GODOT_BENCH_CONTRACT=BLOCKED_PROCESS_EXIT"
    throw "VM01_A3_GODOT_BENCH_CONTRACT failed with exit code $contractExit"
  }
  Write-Host "VM01_A3_GODOT_BENCH_RUNNER=PASS"
} finally {
  Pop-Location
}
