param([string]$RepoRoot=(Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference="Stop"
Set-Location $RepoRoot
$required=@("scripts/runtime/lian_wu_combo_combat_controller.gd","scripts/runtime/lian_wu_combo_chain_gate.gd","scenes/runtime/lian_wu_combo_chain_gate.tscn")
foreach($f in $required){if(-not(Test-Path $f)){throw "VM02_C5_REQUIRED_FILES=BLOCKED missing=$f"}}
Write-Host "VM02_C5_REQUIRED_FILES=PASS"
$godot=Get-Command godot -ErrorAction SilentlyContinue;if(-not $godot){$godot=Get-Command godot4 -ErrorAction SilentlyContinue}
if(-not $godot){$c=Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($c){$godotExe=$c.FullName}else{throw "VM02_C5_GODOT_RESOLVE=BLOCKED"}}else{$godotExe=$godot.Source}
Write-Host "VM02_C5_GODOT_RESOLVE=PASS"
$logDir=Join-Path $RepoRoot ".godot\vm02-c5";New-Item -ItemType Directory -Force -Path $logDir|Out-Null
$stdout=Join-Path $logDir "combo.stdout.log";$stderr=Join-Path $logDir "combo.stderr.log";Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
$args=@("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/lian_wu_combo_chain_gate.tscn","--","--capture-and-quit")
$p=Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if(-not $p.WaitForExit(15000)){try{$p.Kill()}catch{};Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue;throw "VM02_C5_GATE=BLOCKED timeout"}
Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue
$text=(Get-Content $stdout -Raw)+(Get-Content $stderr -Raw)
$markers=@("VM02_C5_TWO_HIT_CHAIN=PASS","VM02_C5_BUFFER_WINDOW=PASS","VM02_C5_NO_IDLE_GAP=PASS","VM02_C5_RUNTIME=PASS","VM02_C5_CAPTURE=PASS")
foreach($m in $markers){if($text -notmatch [regex]::Escape($m)){throw "VM02_C5_GATE=BLOCKED missing_marker=$m"}}
$output=Join-Path $RepoRoot "artifacts\vm02-c5\lian-wu-basic-combo-1920x1080.png";if(-not(Test-Path $output)){throw "VM02_C5_GATE=BLOCKED missing_capture"}
Write-Host "VM02_C5_BASIC_COMBO_GATE=PASS"
Write-Host "VM02_C5_BASIC_COMBO_GATE_OUTPUT=$output"
Write-Host "VM02_C5_BASIC_COMBO_GATE_SHA256=$((Get-FileHash $output -Algorithm SHA256).Hash.ToLower())"
Write-Host "VM02_C5_REVIEW=PENDING_VISUAL_REVIEW"
