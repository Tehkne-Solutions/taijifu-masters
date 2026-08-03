function Write-TehkneGateReport {
    param(
        [Parameter(Mandatory=$true)][string]$Gate,
        [Parameter(Mandatory=$true)][ValidateSet('PASS','BLOCKED')][string]$Status,
        [string[]]$Checks = @(),
        [string]$Artifact = '',
        [string]$Sha256 = '',
        [string]$RepoRoot = (Get-Location).Path,
        [switch]$CopyToClipboard
    )

    $branch = ''
    $commit = ''
    try { $branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim() } catch {}
    try { $commit = (& git -C $RepoRoot rev-parse --short=12 HEAD 2>$null).Trim() } catch {}

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('COPY_REPORT_BEGIN')
    $lines.Add("GATE=$Gate")
    $lines.Add("STATUS=$Status")
    if ($branch) { $lines.Add("BRANCH=$branch") }
    if ($commit) { $lines.Add("COMMIT=$commit") }
    foreach ($check in $Checks) {
        if (-not [string]::IsNullOrWhiteSpace($check)) { $lines.Add($check.Trim()) }
    }
    if ($Artifact) { $lines.Add("ARTIFACT=$Artifact") }
    if ($Sha256) { $lines.Add("SHA256=$Sha256") }
    $lines.Add('COPY_REPORT_END')

    $report = $lines -join [Environment]::NewLine
    Write-Host ''
    Write-Host $report

    if ($CopyToClipboard) {
        try {
            Set-Clipboard -Value $report
            Write-Host 'COPY_REPORT_CLIPBOARD=PASS'
        } catch {
            Write-Host 'COPY_REPORT_CLIPBOARD=UNAVAILABLE'
        }
    }

    return $report
}
