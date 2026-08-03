param([string]$RepoRoot=(Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference="Stop"
Set-Location $RepoRoot
$required=@("scripts/runtime/opponent_ai_foundation.gd","scripts/runtime/opponent_ai_foundation_gate.gd","scenes/runtime/opponent_ai_foundation_gate.tscn")
foreach($f in $required){if(-not(Test-Path $f)){throw "VM02_C8_REQUIRED_FILES=BLOCKED missing=$f"}}
Write-Host "VM02_C8_REQUIRED_FILES=PASS"
$godot=Get-Command godot -ErrorAction SilentlyContinue;if(-not $godot){$godot=Get-Command godot4 -ErrorAction SilentlyContinue}
if(-not $godot){$c=Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($c){$godotExe=$c.FullName}else{throw "VM02_C8_GODOT_RESOLVE=BLOCKED"}}else{$godotExe=$godot.Source}
Write-Host "VM02_C8_GODOT_RESOLVE=PASS";Write-Host "GODOT_EXE=$godotExe"
$logDir=Join-Path $RepoRoot ".godot\vm02-c8";New-Item -ItemType Directory -Force -Path $logDir|Out-Null
$stdout=Join-Path $logDir "opponent-ai.stdout.log";$stderr=Join-Path $logDir "opponent-ai.stderr.log";Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
$args=@("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/opponent_ai_foundation_gate.tscn","--","--capture-and-quit")
$p=Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if(-not $p.WaitForExit(18000)){try{$p.Kill()}catch{};Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue;throw "VM02_C8_GATE=BLOCKED timeout"}
Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue
$text=(Get-Content $stdout -Raw)+(Get-Content $stderr -Raw)
$fatal=@("SCRIPT ERROR","Parse Error","Compile Error","Failed to load script","VM02_C8_WATCHDOG=BLOCKED")
foreach($x in $fatal){if($text -match [regex]::Escape($x)){throw "VM02_C8_GATE=BLOCKED fatal=$x"}}
$markers=@("VM02_C8_AI_APPROACH=PASS","VM02_C8_AI_RANGE_DECISION=PASS","VM02_C8_AI_ATTACK=PASS","VM02_C8_AI_DAMAGE_PLAYER=PASS","VM02_C8_AI_RECEIVES_COUNTER=PASS","VM02_C8_AI_REACTION=PASS","VM02_C8_PLAYER_COUNTER_COMBO=PASS","VM02_C8_RUNTIME=PASS","VM02_C8_CAPTURE=PASS")
foreach($m in $markers){if($text -notmatch [regex]::Escape($m)){throw "VM02_C8_GATE=BLOCKED missing_marker=$m"}}
$output=Join-Path $RepoRoot "artifacts\vm02-c8\lian-wu-opponent-ai-foundation-1920x1080.png";if(-not(Test-Path $output)){throw "VM02_C8_GATE=BLOCKED missing_capture"}
Write-Host "VM02_C8_RUNTIME_PROCESS=PASS"
Write-Host "VM02_C8_OPPONENT_AI_GATE=PASS"
Write-Host "VM02_C8_OPPONENT_AI_GATE_OUTPUT=$output"
Write-Host "VM02_C8_OPPONENT_AI_GATE_SHA256=$((Get-FileHash $output -Algorithm SHA256).Hash.ToLower())"
Write-Host "VM02_C8_REVIEW=PENDING_VISUAL_REVIEW"
