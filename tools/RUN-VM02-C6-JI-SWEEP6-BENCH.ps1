param([string]$RepoRoot=(Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference='Stop'
Set-Location $RepoRoot

$python=(Get-Command py.exe -ErrorAction SilentlyContinue)
if(-not $python){$python=(Get-Command python -ErrorAction SilentlyContinue)}
if(-not $python){throw 'VM02_C6_PYTHON_RESOLVE=BLOCKED'}
Write-Host 'VM02_C6_PYTHON_RESOLVE=PASS'
Write-Host "PYTHON=$($python.Name)"

& $python.Source '.\tools\generate_lian_wu_ji_sweep6.py' --repo-root $RepoRoot
if($LASTEXITCODE -ne 0){throw 'VM02_C6_JI_SWEEP6=BLOCKED_GENERATION'}

$godot=Get-Command godot -ErrorAction SilentlyContinue
if(-not $godot){$godot=Get-Command godot4 -ErrorAction SilentlyContinue}
if(-not $godot){
  $candidate=Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter 'Godot_v*-stable_win64.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if($candidate){$godotExe=$candidate.FullName}else{throw 'VM02_C6_GODOT_RESOLVE=BLOCKED'}
}else{$godotExe=$godot.Source}
Write-Host 'VM02_C6_GODOT_RESOLVE=PASS'
Write-Host "GODOT_EXE=$godotExe"

$logDir=Join-Path $RepoRoot '.godot\vm02-c6'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout=Join-Path $logDir 'ji-sweep6.stdout.log'
$stderr=Join-Path $logDir 'ji-sweep6.stderr.log'
$bootstrapStdout=Join-Path $logDir 'bootstrap.stdout.log'
$bootstrapStderr=Join-Path $logDir 'bootstrap.stderr.log'
Remove-Item $stdout,$stderr,$bootstrapStdout,$bootstrapStderr -Force -ErrorAction SilentlyContinue

$bootstrap=Start-Process -FilePath $godotExe -ArgumentList @('--path',$RepoRoot,'--editor','--headless','--quit-after','3') -WorkingDirectory $RepoRoot -Wait -PassThru -RedirectStandardOutput $bootstrapStdout -RedirectStandardError $bootstrapStderr
if($bootstrap.ExitCode -ne 0){
  Write-Host "VM02_C6_GODOT_BOOTSTRAP=BLOCKED exit=$($bootstrap.ExitCode)"
  if(Test-Path $bootstrapStdout){Get-Content $bootstrapStdout}
  if(Test-Path $bootstrapStderr){Get-Content $bootstrapStderr}
  throw 'VM02_C6_JI_SWEEP6_BENCH=BLOCKED bootstrap'
}
Write-Host 'VM02_C6_GODOT_BOOTSTRAP=PASS'

$args=@('--path',$RepoRoot,'--resolution','1920x1080','res://scenes/runtime/lian_wu_ji_sweep6_visual_bench.tscn','--','--capture-and-quit')
$run=Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$timeoutSeconds=15
if(-not $run.WaitForExit($timeoutSeconds*1000)){
  try{$run.Kill()}catch{}
  Write-Host "VM02_C6_PROCESS_TIMEOUT=BLOCKED seconds=$timeoutSeconds"
  if(Test-Path $stdout){Get-Content $stdout}
  if(Test-Path $stderr){Get-Content $stderr}
  throw 'VM02_C6_JI_SWEEP6_BENCH=BLOCKED process_timeout'
}
$run.WaitForExit()
$run.Refresh()
$exitCodeAvailable=$null -ne $run.ExitCode -and -not [string]::IsNullOrWhiteSpace([string]$run.ExitCode)
if($exitCodeAvailable){
  $exitCode=[int]$run.ExitCode
  Write-Host "VM02_C6_GODOT_RUNTIME_EXIT=$exitCode"
}else{
  $exitCode=$null
  Write-Host 'VM02_C6_GODOT_RUNTIME_EXIT=UNAVAILABLE'
}

if(Test-Path $stdout){Get-Content $stdout}
if(Test-Path $stderr){Get-Content $stderr}
$text=''
if(Test-Path $stdout){$text+=Get-Content $stdout -Raw}
if(Test-Path $stderr){$text+="`n"+(Get-Content $stderr -Raw)}

$fatalPatterns=@('SCRIPT ERROR','Parse Error','Compile Error','Failed to load script')
foreach($pattern in $fatalPatterns){
  if($text -match [regex]::Escape($pattern)){throw "VM02_C6_JI_SWEEP6_BENCH=BLOCKED fatal_marker=$pattern"}
}
if($exitCodeAvailable -and $exitCode -ne 0){throw "VM02_C6_JI_SWEEP6_BENCH=BLOCKED godot_exit=$exitCode"}

$out=Join-Path $RepoRoot 'artifacts\vm02-c6\lian-wu-ji-sweep6-bench-1920x1080.png'
if(-not(Test-Path $out)){throw 'VM02_C6_JI_SWEEP6_BENCH=BLOCKED missing_capture'}

if($text -match 'VM02_C6_JI_SWEEP6_BENCH_CAPTURE=PASS'){
  Write-Host 'VM02_C6_CAPTURE_MARKER=PASS'
}else{
  Write-Host 'VM02_C6_CAPTURE_MARKER=UNAVAILABLE_BUT_CAPTURE_PRESENT'
}

Write-Host 'VM02_C6_RUNTIME_PROCESS=PASS'
Write-Host 'VM02_C6_JI_SWEEP6_BENCH=PASS'
Write-Host "VM02_C6_JI_SWEEP6_BENCH_OUTPUT=$out"
Write-Host "VM02_C6_JI_SWEEP6_BENCH_SHA256=$((Get-FileHash $out -Algorithm SHA256).Hash.ToLower())"
Write-Host 'VM02_C6_JI_SWEEP6_PROMOTION=PENDING_VISUAL_REVIEW'
