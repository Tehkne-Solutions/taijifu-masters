function Write-TehkneGateReport {
    param(
        [Parameter(Mandatory=$true)][string]$Gate,
        [Parameter(Mandatory=$true)][ValidateSet('PASS','BLOCKED')][string]$Status,
        [string[]]$Checks = @(),
        [System.Collections.IDictionary]$Values = $null,
        [string]$Artifact = '',
        [string]$Sha256 = '',
        [string]$RepoRoot = (Get-Location).Path,
        [string]$Branch = '',
        [string]$Commit = '',
        [switch]$CopyToClipboard
    )

    $resolvedBranch = $Branch
    $resolvedCommit = $Commit
    if ([string]::IsNullOrWhiteSpace($resolvedBranch)) {
        try { $resolvedBranch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim() } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($resolvedCommit)) {
        try { $resolvedCommit = (& git -C $RepoRoot rev-parse --short=12 HEAD 2>$null).Trim() } catch {}
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('COPY_REPORT_BEGIN')
    $lines.Add("GATE=$Gate")
    $lines.Add("STATUS=$Status")
    if ($resolvedBranch) { $lines.Add("BRANCH=$resolvedBranch") }
    if ($resolvedCommit) { $lines.Add("COMMIT=$resolvedCommit") }

    foreach ($check in $Checks) {
        if (-not [string]::IsNullOrWhiteSpace($check)) { $lines.Add($check.Trim()) }
    }

    if ($Values -ne $null) {
        foreach ($key in $Values.Keys) {
            $value = $Values[$key]
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                $lines.Add("$key=$value")
            }
        }
    }

    if ($Artifact -and ($Values -eq $null -or -not $Values.Contains('ARTIFACT'))) { $lines.Add("ARTIFACT=$Artifact") }
    if ($Sha256 -and ($Values -eq $null -or -not $Values.Contains('SHA256'))) { $lines.Add("SHA256=$Sha256") }
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
