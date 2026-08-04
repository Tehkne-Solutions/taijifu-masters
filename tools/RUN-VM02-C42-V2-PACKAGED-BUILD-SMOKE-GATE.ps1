param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$required = @(
  "project.godot",
  "config\v2-production-progress.json",
  "tools\RUN-VM02-C41-V2-REPEATABLE-PLAYTEST-PACKAGING-GATE.ps1"
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "VM02_C42_MISSING=$_" }
  throw "VM02_C42_REQUIRED_FILES=BLOCKED"
}
Write-Host "VM02_C42_REQUIRED_FILES=PASS"

$progress = Get-Content (Join-Path $RepoRoot "config\v2-production-progress.json") -Raw | ConvertFrom-Json
if (-not [bool]$progress.v2_playable.runtime_ready) { throw "VM02_C42_RUNTIME_READY=BLOCKED" }
Write-Host "VM02_C42_RUNTIME_READY=PASS"

$workspace = Split-Path $RepoRoot -Parent
$buildRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c41"
if (-not (Test-Path $buildRoot)) { throw "VM02_C42_BUILD_ROOT=BLOCKED path=$buildRoot" }

$zip = Get-ChildItem $buildRoot -Filter "TAIJIFU_MASTERS_V2_PLAYTEST_*.zip" -File |
  Sort-Object LastWriteTimeUtc -Descending |
  Select-Object -First 1
if (-not $zip) { throw "VM02_C42_PACKAGE=BLOCKED no_c41_zip" }
Write-Host "VM02_C42_PACKAGE=PASS path=$($zip.FullName)"

$sha = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "VM02_C42_PACKAGE_SHA256=$sha"

$smokeRoot = Join-Path $workspace "taijifu-masters-builds\vm02-c42"
$extractRoot = Join-Path $smokeRoot "extracted"
$logRoot = Join-Path $smokeRoot "logs"
Remove-Item $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $extractRoot,$logRoot | Out-Null
Expand-Archive -Path $zip.FullName -DestinationPath $extractRoot -Force
Write-Host "VM02_C42_EXTRACT=PASS"

$manifestPath = Join-Path $extractRoot "PLAYTEST-MANIFEST.json"
if (-not (Test-Path $manifestPath)) { throw "VM02_C42_MANIFEST=BLOCKED missing" }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
if ($manifest.product -ne "Taijifu Masters") { throw "VM02_C42_MANIFEST=BLOCKED product" }
if ($manifest.project_version -ne "0.2.2-playtest") { throw "VM02_C42_MANIFEST=BLOCKED version=$($manifest.project_version)" }
if (-not [bool]$manifest.runtime_ready) { throw "VM02_C42_MANIFEST=BLOCKED runtime_ready" }
if ($manifest.canonical_arena -ne "mountain_dojo_night") { throw "VM02_C42_MANIFEST=BLOCKED arena=$($manifest.canonical_arena)" }
Write-Host "VM02_C42_MANIFEST=PASS"

$web = Join-Path $extractRoot "web"
$webRequired = @("index.html","index.js","index.wasm","index.pck")
$webMissing = @($webRequired | Where-Object { -not (Test-Path (Join-Path $web $_)) })
if ($webMissing.Count -gt 0) {
  $webMissing | ForEach-Object { Write-Host "VM02_C42_WEB_MISSING=$_" }
  throw "VM02_C42_WEB_PACKAGE=BLOCKED"
}
$indexText = Get-Content (Join-Path $web "index.html") -Raw
if ($indexText -notmatch 'Taijifu|Godot|canvas') { throw "VM02_C42_WEB_PACKAGE=BLOCKED index_contract" }
Write-Host "VM02_C42_WEB_PACKAGE=PASS files=$($webRequired.Count)/$($webRequired.Count)"

$windows = Join-Path $extractRoot "windows"
$exe = Join-Path $windows "Taijifu-Masters-V2-Playtest.exe"
if (-not (Test-Path $exe)) { throw "VM02_C42_WINDOWS_PACKAGE=BLOCKED exe_missing" }
Write-Host "VM02_C42_WINDOWS_PACKAGE=PASS"

$stdout = Join-Path $logRoot "windows-smoke.stdout.log"
$stderr = Join-Path $logRoot "windows-smoke.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath $exe -ArgumentList @("--headless","--quit-after","3") -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (Test-Path $stdout) { Get-Content $stdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $stderr) { Get-Content $stderr | ForEach-Object { Write-Host $_ } }
if ($proc.ExitCode -ne 0) { throw "VM02_C42_WINDOWS_BOOT=BLOCKED exit=$($proc.ExitCode)" }
Write-Host "VM02_C42_WINDOWS_BOOT=PASS exit=0"

$combined = ""
if (Test-Path $stdout) { $combined += (Get-Content $stdout -Raw) }
if (Test-Path $stderr) { $combined += "`n" + (Get-Content $stderr -Raw) }
$fatalPatterns = @("SCRIPT ERROR:","Parse Error:","Failed to load script","Segmentation fault","CRASH")
$fatalHits = @($fatalPatterns | Where-Object { $combined -match [regex]::Escape($_) })
if ($fatalHits.Count -gt 0) {
  $fatalHits | ForEach-Object { Write-Host "VM02_C42_FATAL_SIGNATURE=$_" }
  throw "VM02_C42_RUNTIME_LOG=BLOCKED"
}
Write-Host "VM02_C42_RUNTIME_LOG=PASS"

Write-Host "VM02_C42_ART_COMPLETE=BLOCKED expected_pending_art"
Write-Host "VM02_C42_TRAINING_RIVAL_ART=ISOLATED_PENDING"
Write-Host "VM02_C42_PACKAGED_BUILD_SMOKE=PASS"

$branch = (git -C $RepoRoot branch --show-current).Trim()
$commit = (git -C $RepoRoot rev-parse --short=12 HEAD).Trim()
$report = @(
  "COPY_REPORT_BEGIN",
  "GATE=VM02-C42-V2-PACKAGED-BUILD-SMOKE",
  "STATUS=PASS",
  "BRANCH=$branch",
  "COMMIT=$commit",
  "RUNTIME_READY=PASS",
  "PACKAGE=PASS",
  "MANIFEST=PASS",
  "WEB_PACKAGE=PASS",
  "WINDOWS_PACKAGE=PASS",
  "WINDOWS_BOOT=PASS",
  "RUNTIME_LOG=PASS",
  "ART_COMPLETE=BLOCKED",
  "TRAINING_RIVAL_ART=ISOLATED_PENDING",
  "PHASE_PROGRESS=99%",
  "V2_PLAYABLE_PROGRESS=64%",
  "PROJECT_PROGRESS=48%",
  "ARTIFACT=$($zip.FullName)",
  "SHA256=$sha",
  "COPY_REPORT_END"
)
$report | ForEach-Object { Write-Host $_ }
try { ($report -join [Environment]::NewLine) | Set-Clipboard; Write-Host "COPY_REPORT_CLIPBOARD=PASS" } catch { Write-Host "COPY_REPORT_CLIPBOARD=BLOCKED" }
Write-Host "VM02_C42_V2_PACKAGED_BUILD_SMOKE_GATE=PASS"
Write-Host "Tehkne Solutions"
