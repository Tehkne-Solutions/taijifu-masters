param([string]$RepoRoot='.')
$ErrorActionPreference='Stop'; $RepoRoot=(Resolve-Path $RepoRoot).Path
function Resolve-Python { foreach($n in @('py','python','python3')){ if(Get-Command $n -ErrorAction SilentlyContinue){ return $n } }; return $null }
function Probe([string]$Command,[string[]]$Arguments){ $old=$ErrorActionPreference; try{$ErrorActionPreference='Continue'; $out=& $Command @Arguments 2>&1; $code=$LASTEXITCODE}finally{$ErrorActionPreference=$old}; [pscustomobject]@{ExitCode=$code;Output=@($out)} }
$python=Resolve-Python; if(-not $python){Write-Host 'VM02_A7_FALL3=BLOCKED_PYTHON_NOT_FOUND'; exit 2}
Write-Host 'VM02_A7_PYTHON_RESOLVE=PASS'; Write-Host "PYTHON=$python"
$p=Probe $python @('-c','import PIL; print(PIL.__version__)'); if($p.ExitCode -ne 0){$i=Probe $python @('-m','pip','install','Pillow'); if($i.ExitCode -ne 0){Write-Host 'VM02_A7_FALL3=BLOCKED_PILLOW_INSTALL'; exit 3}; $p=Probe $python @('-c','import PIL; print(PIL.__version__)')}
if($p.ExitCode -ne 0){Write-Host 'VM02_A7_FALL3=BLOCKED_PILLOW_IMPORT'; exit 3}; Write-Host 'VM02_A7_PILLOW=PASS'; Write-Host "PILLOW_VERSION=$($p.Output|Select-Object -Last 1)"
$g=Join-Path $RepoRoot 'tools\generate_lian_wu_fall3.py'; if(-not(Test-Path $g)){Write-Host 'VM02_A7_FALL3=BLOCKED_GENERATOR_MISSING'; exit 4}
& $python $g --repo-root $RepoRoot; if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
$v=Join-Path $RepoRoot 'tools\validate_lian_wu_locomotion_core.py'; if(Test-Path $v){$old=$ErrorActionPreference; try{$ErrorActionPreference='Continue'; & $python $v; $ve=$LASTEXITCODE}finally{$ErrorActionPreference=$old}; Write-Host "VM02_A7_LOCOMOTION_VALIDATOR_EXIT=$ve"}
Write-Host 'VM02_A7_FALL3=READY_FOR_GODOT_REVIEW'
