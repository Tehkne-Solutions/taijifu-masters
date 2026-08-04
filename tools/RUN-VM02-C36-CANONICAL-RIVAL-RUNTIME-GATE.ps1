param([string]$RepoRoot=(Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference="Stop"
Set-Location $RepoRoot

$scene="scenes/runtime/v2_canonical_rival_binding_gate.tscn"
$script="scripts/runtime/v2_canonical_rival_binding_gate.gd"
$rivalScript="scripts/runtime/opponent_visual_sparring_rival.gd"
$c28="tools/RUN-VM02-C28-V2-RIVAL-INTAKE-GATE.ps1"
$reportLib="tools/lib/Write-TehkneGateReport.ps1"
$progressPath="config/v2-production-progress.json"
foreach($f in @($scene,$script,$rivalScript,$c28,$reportLib,$progressPath)){if(-not(Test-Path $f)){throw "VM02_C36_REQUIRED_FILES=BLOCKED missing=$f"}}
Write-Host "VM02_C36_REQUIRED_FILES=PASS"

Write-Host "VM02_C36_C28_PREFLIGHT=BEGIN"
$c28Output=& powershell -ExecutionPolicy Bypass -File $c28 -RepoRoot $RepoRoot 2>&1
if($LASTEXITCODE -ne 0){$c28Output|ForEach-Object{Write-Host $_};throw "VM02_C36_C28_PREFLIGHT=BLOCKED exit=$LASTEXITCODE"}
$c28Text=$c28Output -join "`n"
$c28Output|Where-Object{$_ -match '^VM02_C28_(RIVAL_FRAME_COUNT|RIVAL_FRAME_CONTRACT|RIVAL_IMPORT|RIVAL_CANONICAL_READY|PIPELINE_READY)='}|ForEach-Object{Write-Host $_}
if($c28Text -notmatch 'VM02_C28_PIPELINE_READY=PASS'){throw "VM02_C36_C28_PREFLIGHT=BLOCKED pipeline"}
Write-Host "VM02_C36_C28_PREFLIGHT=PASS"

$frameCount="0/44"
if($c28Text -match 'VM02_C28_RIVAL_FRAME_COUNT=([^\r\n]+)'){$frameCount=$Matches[1].Trim()}
$canonicalImported=$c28Text -match 'VM02_C28_RIVAL_CANONICAL_READY=PASS'

$godot=Get-Command godot -ErrorAction SilentlyContinue
if(-not $godot){$godot=Get-Command godot4 -ErrorAction SilentlyContinue}
if(-not $godot){$candidate=Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue|Sort-Object FullName -Descending|Select-Object -First 1;if($candidate){$godotExe=$candidate.FullName}else{throw "VM02_C36_GODOT_RESOLVE=BLOCKED"}}else{$godotExe=$godot.Source}
Write-Host "VM02_C36_GODOT_RESOLVE=PASS"
Write-Host "GODOT_EXE=$godotExe"

$logDir=Join-Path $RepoRoot ".godot\vm02-c36";New-Item -ItemType Directory -Force -Path $logDir|Out-Null
$stdout=Join-Path $logDir "canonical-rival-binding.stdout.log";$stderr=Join-Path $logDir "canonical-rival-binding.stderr.log";Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
$args=@("--path",$RepoRoot,"--resolution","1920x1080","res://$scene")
$p=Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if(-not $p.WaitForExit(20000)){try{$p.Kill()}catch{};Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue;throw "VM02_C36_GATE=BLOCKED timeout"}
Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue
$text=(Get-Content $stdout -Raw -ErrorAction SilentlyContinue)+(Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
foreach($fatal in @("SCRIPT ERROR","Parse Error","Compile Error","Failed to load script","canonical rival runtime binding contract failed","rival binding viewport capture unavailable","rival binding capture save failed")){if($text -match [regex]::Escape($fatal)){throw "VM02_C36_GATE=BLOCKED fatal=$fatal"}}
$markers=@("VM02_C36_VISUAL_READY=PASS","VM02_C36_STATE_COVERAGE=PASS","VM02_C36_IDENTITY_CONTRACT=PASS","VM02_C36_FACING_CONTRACT=PASS","VM02_C36_RUNTIME_BINDING=PASS","VM02_C36_CAPTURE=PASS","VM02_C36_RUNTIME=PASS")
foreach($m in $markers){if($text -notmatch [regex]::Escape($m)){throw "VM02_C36_GATE=BLOCKED missing_marker=$m"}}

$runtimeCanonical=$text -match 'VM02_C36_CANONICAL_ACTIVE=PASS'
if($canonicalImported -and -not $runtimeCanonical){throw "VM02_C36_GATE=BLOCKED imported_but_runtime_proxy"}
if(-not $canonicalImported -and $text -notmatch 'VM02_C36_PROXY_FALLBACK=PASS'){throw "VM02_C36_GATE=BLOCKED proxy_fallback_missing"}

$output=Join-Path $RepoRoot "artifacts\vm02-c36\canonical-rival-binding-1920x1080.png"
if(-not(Test-Path $output)){throw "VM02_C36_GATE=BLOCKED missing_capture"}
$sha=(Get-FileHash $output -Algorithm SHA256).Hash.ToLower()
Write-Host "VM02_C36_CANONICAL_RUNTIME_READY=$(if($runtimeCanonical){'PASS'}else{'BLOCKED'})"
Write-Host "VM02_C36_PROXY_RETIREMENT=$(if($runtimeCanonical){'PASS'}else{'BLOCKED'})"
Write-Host "VM02_C36_RUNTIME_PIPELINE=PASS"
Write-Host "VM02_C36_CANONICAL_RIVAL_RUNTIME_GATE=PASS"
Write-Host "VM02_C36_OUTPUT=$output"
Write-Host "VM02_C36_SHA256=$sha"

. $reportLib
$progress=Get-Content $progressPath -Raw|ConvertFrom-Json
$branchName=(git branch --show-current).Trim();$commit=(git rev-parse --short=12 HEAD).Trim()
Write-TehkneGateReport -Gate "VM02-C36-CANONICAL-RIVAL-RUNTIME-BINDING" -Status "PASS" -Branch $branchName -Commit $commit -Values ([ordered]@{
  C28_PREFLIGHT="PASS"
  FRAME_COUNT=$frameCount
  CANONICAL_IMPORTED=$(if($canonicalImported){"PASS"}else{"BLOCKED"})
  VISUAL_READY="PASS"
  STATE_COVERAGE="PASS"
  IDENTITY_CONTRACT="PASS"
  FACING_CONTRACT="PASS"
  RUNTIME_BINDING="PASS"
  PROXY_RETIREMENT=$(if($runtimeCanonical){"PASS"}else{"BLOCKED"})
  CANONICAL_RUNTIME_READY=$(if($runtimeCanonical){"PASS"}else{"BLOCKED"})
  PIPELINE_READY="PASS"
  CAPTURE="PASS"
  ARTIFACT=$output
  SHA256=$sha
  PHASE_PROGRESS="$($progress.phase.progress_percent)%"
  V2_PLAYABLE_PROGRESS="$($progress.v2_playable.progress_percent)%"
  PROJECT_PROGRESS="$($progress.project.progress_percent)%"
}) -CopyToClipboard

# Tehkné Solutions
