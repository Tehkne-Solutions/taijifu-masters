param([string]$RepoRoot=(Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference="Stop"
Set-Location $RepoRoot

$scene="scenes/runtime/v2_canonical_arena_visual_proof.tscn"
$script="scripts/runtime/v2_canonical_arena_visual_proof.gd"
$c34="tools/RUN-VM02-C34-V2-ARENA-RUNTIME-GATE.ps1"
$reportLib="tools/lib/Write-TehkneGateReport.ps1"
$progressPath="config/v2-production-progress.json"
foreach($f in @($scene,$script,$c34,$reportLib,$progressPath)){if(-not(Test-Path $f)){throw "VM02_C35_REQUIRED_FILES=BLOCKED missing=$f"}}
Write-Host "VM02_C35_REQUIRED_FILES=PASS"

Write-Host "VM02_C35_C34_PREFLIGHT=BEGIN"
$c34Output=& powershell -ExecutionPolicy Bypass -File $c34 -RepoRoot $RepoRoot 2>&1
if($LASTEXITCODE -ne 0){$c34Output|ForEach-Object{Write-Host $_};throw "VM02_C35_C34_PREFLIGHT=BLOCKED exit=$LASTEXITCODE"}
$c34Output|Where-Object{$_ -match '^VM02_C34_(AUTO_INTAKE|ARENA_IMPORTED|ARENA_FILE_COUNT|PARALLAX_CONTRACT|RUNTIME_BINDING|PROCEDURAL_RETIREMENT|MANIFEST_CONTRACT|GROUND_ALIGNMENT|CANONICAL_RUNTIME_READY)='}|ForEach-Object{Write-Host $_}
if(($c34Output -join "`n") -notmatch 'VM02_C34_CANONICAL_RUNTIME_READY=PASS'){throw "VM02_C35_C34_PREFLIGHT=BLOCKED canonical_not_ready"}
Write-Host "VM02_C35_C34_PREFLIGHT=PASS"

$godot=Get-Command godot -ErrorAction SilentlyContinue
if(-not $godot){$godot=Get-Command godot4 -ErrorAction SilentlyContinue}
if(-not $godot){$candidate=Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue|Sort-Object FullName -Descending|Select-Object -First 1;if($candidate){$godotExe=$candidate.FullName}else{throw "VM02_C35_GODOT_RESOLVE=BLOCKED"}}else{$godotExe=$godot.Source}
Write-Host "VM02_C35_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir=Join-Path $RepoRoot ".godot\vm02-c35"
New-Item -ItemType Directory -Force -Path $logDir|Out-Null
$stdout=Join-Path $logDir "canonical-arena-visual-proof.stdout.log"
$stderr=Join-Path $logDir "canonical-arena-visual-proof.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
$args=@("--path",$RepoRoot,"--resolution","1920x1080","res://$scene")
$p=Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if(-not $p.WaitForExit(20000)){try{$p.Kill()}catch{};Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue;throw "VM02_C35_GATE=BLOCKED timeout"}
Get-Content $stdout -ErrorAction SilentlyContinue
Get-Content $stderr -ErrorAction SilentlyContinue
$text=(Get-Content $stdout -Raw -ErrorAction SilentlyContinue)+(Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
foreach($fatal in @("SCRIPT ERROR","Parse Error","Compile Error","Failed to load script","canonical arena visual runtime contract failed","viewport capture unavailable","capture save failed")){if($text -match [regex]::Escape($fatal)){throw "VM02_C35_GATE=BLOCKED fatal=$fatal"}}
$markers=@("VM02_C35_CANONICAL_ARENA_ACTIVE=PASS","VM02_C35_CANONICAL_ARENA_ID=mountain_dojo_night","VM02_C35_PARALLAX_NODE=PASS","VM02_C35_PROCEDURAL_RETIRED=PASS","VM02_C35_CAPTURE_NORMALIZED=PASS","VM02_C35_CAPTURE=PASS","VM02_C35_RUNTIME=PASS")
foreach($m in $markers){if($text -notmatch [regex]::Escape($m)){throw "VM02_C35_GATE=BLOCKED missing_marker=$m"}}
$output=Join-Path $RepoRoot "artifacts\vm02-c35\mountain-dojo-night-runtime-1920x1080.png"
if(-not(Test-Path $output)){throw "VM02_C35_GATE=BLOCKED missing_capture"}
$sha=(Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C35_VISUAL_PROOF_GATE=PASS"
Write-Host "VM02_C35_VISUAL_PROOF_OUTPUT=$output"
Write-Host "VM02_C35_VISUAL_PROOF_SHA256=$sha"
Write-Host "VM02_C35_REVIEW=PENDING_VISUAL_REVIEW"

. $reportLib
$progress=Get-Content $progressPath -Raw|ConvertFrom-Json
$branchName=(git branch --show-current).Trim()
$commit=(git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C35-CANONICAL-ARENA-VISUAL-PROOF" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  C34_PREFLIGHT="PASS"
  CANONICAL_ARENA="PASS"
  PARALLAX_NODE="PASS"
  PROCEDURAL_RETIRED="PASS"
  CAPTURE="PASS"
  RUNTIME="PASS"
  ARTIFACT=$output
  SHA256=$sha
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard

# Tehkné Solutions
