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

$python = Get-Command py -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) { Write-Host "VM02_C2_PYTHON_RESOLVE=BLOCKED"; exit 2 }
Write-Host "VM02_C2_PYTHON_RESOLVE=PASS"
Write-Host "PYTHON=$($python.Name)"

& $python.Source -c "import PIL; print('VM02_C2_PILLOW=PASS'); print('PILLOW_VERSION=' + PIL.__version__)"
if ($LASTEXITCODE -ne 0) { Write-Host "VM02_C2_PILLOW=BLOCKED"; exit 3 }

& $python.Source (Join-Path $RepoRoot "tools\generate_lian_wu_body_hook6.py") --repo-root $RepoRoot
if ($LASTEXITCODE -ne 0) { Write-Host "VM02_C2_BODY_HOOK6=BLOCKED_GENERATION"; exit 4 }

$godot = Resolve-GodotExecutable -Explicit $GodotExe
if (-not $godot) { Write-Host "VM02_C2_GODOT_RESOLVE=BLOCKED"; exit 5 }
Write-Host "VM02_C2_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godot"

$artifactDir = Join-Path $RepoRoot "artifacts\vm02-c2"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$output = Join-Path $artifactDir "lian-wu-body-hook6-bench-1920x1080.png"
if (Test-Path $output) { Remove-Item $output -Force }

$logDir = Join-Path $RepoRoot ".godot\vm02-c2"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir "body-hook6.stdout.log"
$stderr = Join-Path $logDir "body-hook6.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue

$args = @(
  "--path", $RepoRoot,
  "--resolution", "1920x1080",
  "res://scenes/runtime/lian_wu_body_hook6_visual_bench.tscn",
  "--",
  "--capture-and-quit"
)
$process = Start-Process -FilePath $godot -ArgumentList $args -WorkingDirectory $RepoRoot -Wait -PassThru `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr

$combined = @()
if (Test-Path $stdout) { $combined += Get-Content $stdout }
if (Test-Path $stderr) { $combined += Get-Content $stderr }
foreach ($line in $combined) { Write-Host $line }

$fatal = @($combined | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script" })
$requiredPass = @(
  "VM02_C2_BODY_HOOK6_BENCH_CAPTURE=PASS"
)
foreach ($marker in $requiredPass) {
  if (-not ($combined -contains $marker)) {
    Write-Host "VM02_C2_BODY_HOOK6_BENCH=BLOCKED missing_marker=$marker"
    Write-Host "STDOUT=$stdout"
    Write-Host "STDERR=$stderr"
    exit 6
  }
}
if ($process.ExitCode -ne 0 -or $fatal.Count -gt 0 -or -not (Test-Path $output)) {
  Write-Host "VM02_C2_BODY_HOOK6_BENCH=BLOCKED"
  Write-Host "STDOUT=$stdout"
  Write-Host "STDERR=$stderr"
  exit 7
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($output)
try {
  if ($image.Width -ne 1920 -or $image.Height -ne 1080) {
    Write-Host "VM02_C2_BODY_HOOK6_BENCH=BLOCKED_SIZE"
    exit 8
  }
} finally { $image.Dispose() }

$hash = (Get-FileHash $output -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C2_BODY_HOOK6_BENCH=PASS"
Write-Host "VM02_C2_BODY_HOOK6_BENCH_OUTPUT=$output"
Write-Host "VM02_C2_BODY_HOOK6_BENCH_SHA256=$hash"
Write-Host "VM02_C2_BODY_HOOK6_PROMOTION=PENDING_VISUAL_REVIEW"
