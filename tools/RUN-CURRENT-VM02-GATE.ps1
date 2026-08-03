param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
  [switch]$NoPull
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$branch = (git branch --show-current).Trim()
if (-not $branch) { throw "VM02_CURRENT_GATE=BLOCKED no_branch" }

if ($branch -notmatch '^vm02-(c\d+)-') {
  throw "VM02_CURRENT_GATE=BLOCKED unsupported_branch=$branch"
}

$gateId = $Matches[1].ToUpper()
$pattern = "RUN-VM02-$gateId-*-GATE.ps1"
$matches = @(Get-ChildItem (Join-Path $RepoRoot "tools") -Filter $pattern -File)

if ($matches.Count -eq 0) {
  throw "VM02_CURRENT_GATE=BLOCKED gate_not_found pattern=$pattern"
}
if ($matches.Count -gt 1) {
  $names = ($matches | ForEach-Object Name) -join ','
  throw "VM02_CURRENT_GATE=BLOCKED ambiguous_gate files=$names"
}

$gateScript = $matches[0].FullName
Write-Host "VM02_CURRENT_GATE_BRANCH=$branch"
Write-Host "VM02_CURRENT_GATE_ID=$gateId"
Write-Host "VM02_CURRENT_GATE_SCRIPT=$($matches[0].Name)"

if (-not $NoPull) {
  Write-Host "VM02_CURRENT_GATE_SYNC=BEGIN"
  git fetch origin
  if ($LASTEXITCODE -ne 0) { throw "VM02_CURRENT_GATE=BLOCKED git_fetch" }
  git pull --ff-only origin $branch
  if ($LASTEXITCODE -ne 0) { throw "VM02_CURRENT_GATE=BLOCKED git_pull" }
  Write-Host "VM02_CURRENT_GATE_SYNC=PASS"
}

$logDir = Join-Path $RepoRoot "artifacts\gate-reports"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "$gateId-$stamp.log"

Write-Host "VM02_CURRENT_GATE_RUN=BEGIN"
& powershell -ExecutionPolicy Bypass -File $gateScript -RepoRoot $RepoRoot 2>&1 | Tee-Object -FilePath $logFile
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
  Write-Host "VM02_CURRENT_GATE_LOG=$logFile"
  throw "VM02_CURRENT_GATE=BLOCKED exit=$exitCode"
}

Write-Host "VM02_CURRENT_GATE_LOG=$logFile"
Write-Host "VM02_CURRENT_GATE=PASS gate=$gateId"
