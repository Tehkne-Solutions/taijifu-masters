param([string]$RepoRoot=(Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference="Stop"
Set-Location $RepoRoot
$required=@("scripts/runtime/lian_wu_body_hook_sweep_combo_controller.gd","scripts/runtime/lian_wu_body_hook_sweep_combo_gate.gd","scenes/runtime/lian_wu_body_hook_sweep_combo_gate.tscn")
foreach($f in $required){if(-not(Test-Path $f)){throw "VM02_C7_REQUIRED_FILES=BLOCKED missing=$f"}}
Write-Host "VM02_C7_REQUIRED_FILES=PASS"
$godot=Get-Command godot -ErrorAction SilentlyContinue;if(-not $godot){$godot=Get-Command godot4 -ErrorAction SilentlyContinue}
if(-not $godot){$c=Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Godot_v*-stable_win64.exe" -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($c){$godotExe=$c.FullName}else{throw "VM02_C7_GODOT_RESOLVE=BLOCKED"}}else{$godotExe=$godot.Source}
Write-Host "VM02_C7_GODOT_RESOLVE=PASS"
$logDir=Join-Path $RepoRoot ".godot\vm02-c7";New-Item -ItemType Directory -Force -Path $logDir|Out-Null
$stdout=Join-Path $logDir "combo.stdout.log";$stderr=Join-Path $logDir "combo.stderr.log";Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
$args=@("--path",$RepoRoot,"--resolution","1920x1080","res://scenes/runtime/lian_wu_body_hook_sweep_combo_gate.tscn","--","--capture-and-quit")
$p=Start-Process -FilePath $godotExe -ArgumentList $args -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if(-not $p.WaitForExit(18000)){try{$p.Kill()}catch{};Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue;throw "VM02_C7_GATE=BLOCKED timeout"}
Get-Content $stdout -ErrorAction SilentlyContinue;Get-Content $stderr -ErrorAction SilentlyContinue
$text=(Get-Content $stdout -Raw)+(Get-Content $stderr -Raw)
$fatal=@("SCRIPT ERROR","Parse Error","Compile Error","Failed to load script","VM02_C7_WATCHDOG=BLOCKED")
foreach($m in $fatal){if($text -match [regex]::Escape($m)){throw "VM02_C7_GATE=BLOCKED fatal_marker=$m"}}
$markers=@("VM02_C7_DISTINCT_LINKS=PASS","VM02_C7_TWO_HIT_CHAIN=PASS","VM02_C7_BUFFER_WINDOW=PASS","VM02_C7_NO_IDLE_GAP=PASS","VM02_C7_COMPLETED_COMBO_COUNT=PASS","VM02_C7_DAMAGE_CONTRACT=PASS","VM02_C7_RUNTIME=PASS","VM02_C7_CAPTURE=PASS")
foreach($m in $markers){if($text -notmatch [regex]::Escape($m)){throw "VM02_C7_GATE=BLOCKED missing_marker=$m"}}
$output=Join-Path $RepoRoot "artifacts\vm02-c7\lian-wu-body-hook-sweep-combo-1920x1080.png";if(-not(Test-Path $output)){throw "VM02_C7_GATE=BLOCKED missing_capture"}
Write-Host "VM02_C7_BODY_HOOK_SWEEP_COMBO_GATE=PASS"
Write-Host "VM02_C7_BODY_HOOK_SWEEP_COMBO_GATE_OUTPUT=$output"
Write-Host "VM02_C7_BODY_HOOK_SWEEP_COMBO_GATE_SHA256=$((Get-FileHash $output -Algorithm SHA256).Hash.ToLower())"
Write-Host "VM02_C7_REVIEW=PENDING_VISUAL_REVIEW"
