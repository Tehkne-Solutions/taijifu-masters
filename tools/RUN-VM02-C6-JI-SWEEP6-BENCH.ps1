param([string]$RepoRoot=(Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference='Stop'; Set-Location $RepoRoot
$python=(Get-Command py.exe -ErrorAction SilentlyContinue); if(-not $python){$python=(Get-Command python -ErrorAction SilentlyContinue)}; if(-not $python){throw 'VM02_C6_PYTHON_RESOLVE=BLOCKED'}
Write-Host 'VM02_C6_PYTHON_RESOLVE=PASS'; Write-Host "PYTHON=$($python.Name)"
& $python.Source '.\tools\generate_lian_wu_ji_sweep6.py' --repo-root $RepoRoot
if($LASTEXITCODE -ne 0){throw "VM02_C6_JI_SWEEP6=BLOCKED_GENERATION"}
$godot=Get-Command godot -ErrorAction SilentlyContinue; if(-not $godot){$godot=Get-Command godot4 -ErrorAction SilentlyContinue}
if(-not $godot){$candidate=Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter 'Godot_v*-stable_win64.exe' -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1; if($candidate){$godotExe=$candidate.FullName}else{throw 'VM02_C6_GODOT_RESOLVE=BLOCKED'}}else{$godotExe=$godot.Source}
Write-Host 'VM02_C6_GODOT_RESOLVE=PASS'; Write-Host "GODOT_EXE=$godotExe"
$logDir=Join-Path $RepoRoot '.godot\vm02-c6'; New-Item -ItemType Directory -Force -Path $logDir|Out-Null
$stdout=Join-Path $logDir 'ji-sweep6.stdout.log'; $stderr=Join-Path $logDir 'ji-sweep6.stderr.log'
& $godotExe --path $RepoRoot --resolution 1920x1080 'res://scenes/runtime/lian_wu_ji_sweep6_visual_bench.tscn' -- --capture-and-quit 1>$stdout 2>$stderr
Get-Content $stdout; if(Test-Path $stderr){Get-Content $stderr}
$text=(Get-Content $stdout -Raw)+"`n"+(Get-Content $stderr -Raw)
if($text -notmatch 'VM02_C6_JI_SWEEP6_BENCH_CAPTURE=PASS'){throw 'VM02_C6_JI_SWEEP6_BENCH=BLOCKED missing_marker=VM02_C6_JI_SWEEP6_BENCH_CAPTURE=PASS'}
$out=Join-Path $RepoRoot 'artifacts\vm02-c6\lian-wu-ji-sweep6-bench-1920x1080.png'; if(-not(Test-Path $out)){throw 'VM02_C6_JI_SWEEP6_BENCH=BLOCKED missing_capture'}
Write-Host 'VM02_C6_JI_SWEEP6_BENCH=PASS'; Write-Host "VM02_C6_JI_SWEEP6_BENCH_OUTPUT=$out"; Write-Host "VM02_C6_JI_SWEEP6_BENCH_SHA256=$((Get-FileHash $out -Algorithm SHA256).Hash.ToLower())"; Write-Host 'VM02_C6_JI_SWEEP6_PROMOTION=PENDING_VISUAL_REVIEW'
