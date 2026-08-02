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

function Resolve-ConsoleExecutable {
  param([string]$ResolvedGodot)
  if ([string]::IsNullOrWhiteSpace($ResolvedGodot)) { return $ResolvedGodot }
  if ($ResolvedGodot -match "_console\.exe$") { return $ResolvedGodot }
  $console = $ResolvedGodot -replace "\.exe$", "_console.exe"
  if (Test-Path $console) { return (Resolve-Path $console).Path }
  return $ResolvedGodot
}

function Invoke-GodotCaptured {
  param(
    [string]$Exe,
    [string[]]$Arguments,
    [string]$LogPrefix
  )

  $logDir = Join-Path $RepoRoot ".godot\vm01-a3"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  $stdout = Join-Path $logDir "$LogPrefix.stdout.log"
  $stderr = Join-Path $logDir "$LogPrefix.stderr.log"
  Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue

  $process = Start-Process -FilePath $Exe -ArgumentList $Arguments -WorkingDirectory $RepoRoot -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr

  $combined = @()
  if (Test-Path $stdout) { $combined += Get-Content $stdout }
  if (Test-Path $stderr) { $combined += Get-Content $stderr }

  foreach ($line in $combined) { Write-Host $line }

  return @{
    ExitCode = $process.ExitCode
    Stdout = $stdout
    Stderr = $stderr
    Combined = $combined
  }
}

$godot = Resolve-GodotExecutable -Explicit $GodotExe
if (-not $godot) {
  Write-Host "VM01_A3_GODOT_RESOLVE=BLOCKED"
  Write-Host "Godot executable was not found automatically."
  Write-Host "Install Godot 4.x or rerun with:"
  Write-Host '  .\tools\RUN-VM01-A3-BENCH.ps1 -RepoRoot "." -GodotExe "C:\path\Godot_v4.x-stable_win64.exe"'
  exit 2
}

$godotCli = Resolve-ConsoleExecutable -ResolvedGodot $godot
Write-Host "VM01_A3_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"
Write-Host "GODOT_CLI_EXE=$godotCli"

Push-Location $RepoRoot
try {
  Write-Host "VM01_A3_GODOT_BOOTSTRAP=RUNNING"
  $bootstrap = Invoke-GodotCaptured -Exe $godotCli -Arguments @("--editor", "--headless", "--path", ".", "--quit", "--verbose") -LogPrefix "bootstrap"
  if ($bootstrap.ExitCode -ne 0) {
    Write-Host "VM01_A3_GODOT_BOOTSTRAP=BLOCKED"
    Write-Host "BOOTSTRAP_STDOUT=$($bootstrap.Stdout)"
    Write-Host "BOOTSTRAP_STDERR=$($bootstrap.Stderr)"
    Write-Host "VM01_A3_ROOT_ERROR_BEGIN"
    $rootLines = $bootstrap.Combined | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|ERROR:" } | Select-Object -First 30
    if ($rootLines.Count -eq 0) {
      $rootLines = $bootstrap.Combined | Select-Object -First 30
    }
    foreach ($line in $rootLines) { Write-Host $line }
    Write-Host "VM01_A3_ROOT_ERROR_END"
    throw "VM01_A3_GODOT_BOOTSTRAP failed with exit code $($bootstrap.ExitCode)"
  }
  Write-Host "VM01_A3_GODOT_BOOTSTRAP=PASS"

  $contract = Invoke-GodotCaptured -Exe $godotCli -Arguments @("--headless", "--path", ".", "--script", "res://tests/lian_wu_character_lock_bench_contract.gd") -LogPrefix "contract"
  if ($contract.ExitCode -ne 0) {
    Write-Host "VM01_A3_GODOT_BENCH_CONTRACT=BLOCKED_PROCESS_EXIT"
    Write-Host "CONTRACT_STDOUT=$($contract.Stdout)"
    Write-Host "CONTRACT_STDERR=$($contract.Stderr)"
    throw "VM01_A3_GODOT_BENCH_CONTRACT failed with exit code $($contract.ExitCode)"
  }
  Write-Host "VM01_A3_GODOT_BENCH_RUNNER=PASS"
} finally {
  Pop-Location
}
