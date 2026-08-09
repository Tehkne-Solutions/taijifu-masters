param(
    [string]$RepoRoot = "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters",
    [string]$StashMessage = "backup-local-before-c56-canonical",
    [string]$Branch = "agent/c63-2-lian-character-lock-exact-recovery"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Expected = [ordered]@{
    "assets/characters/lian_wu/character_lock/lian_wu_neutral.png" = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
    "assets/characters/lian_wu/character_lock/lian_wu_combat_stance.png" = "c8e6cd1feece7c2a54cf2279085c2a4bb33338dd6a3dcb3e4d5a2402b537631c"
}
$ExpectedPaths = [string[]]@($Expected.Keys)

function Fail([string]$Message) {
    Write-Host "C63_2_EXACT_RECOVERY=BLOCKED $Message" -ForegroundColor Red
    exit 1
}

function Invoke-RepoGit([string[]]$GitArgs) {
    $result = & git -C $RepoRoot @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail ("git_failed=" + ($GitArgs -join " ") + " output=" + ($result -join " | "))
    }
    return $result
}

function Assert-Png1024Rgba([string]$Path, [string]$Label) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 26) { Fail "png_too_small=$Label" }
    $signature = ($bytes[0..7] | ForEach-Object { $_.ToString("x2") }) -join ""
    if ($signature -ne "89504e470d0a1a0a") { Fail "png_signature_invalid=$Label" }
    $width = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
    $height = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]
    $bitDepth = [int]$bytes[24]
    $colorType = [int]$bytes[25]
    if ($width -ne 1024 -or $height -ne 1024) { Fail "png_dimensions_invalid=$Label ${width}x${height}" }
    if ($bitDepth -ne 8 -or $colorType -ne 6) { Fail "png_rgba_invalid=$Label bit_depth=$bitDepth color_type=$colorType" }
}

Write-Host "=== TEHKNÉ SOLUTIONS — C63.2 EXACT CHARACTER LOCK RECOVERY ==="
Write-Host "POLICY=NO_STASH_POP_NO_PRIMARY_WORKTREE_MUTATION_NO_REDRAW"

if (-not (Test-Path $RepoRoot)) { Fail "repo_not_found=$RepoRoot" }
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) { Fail "not_git_repo=$RepoRoot" }

$stashLines = @(Invoke-RepoGit @("stash", "list", "--format=%gd%x09%gs"))
$match = $stashLines | Where-Object { $_ -like "*$StashMessage*" } | Select-Object -First 1
if (-not $match) { Fail "stash_message_not_found=$StashMessage" }
$stashRef = (($match -split "`t", 2)[0]).Trim()
if (-not $stashRef) { Fail "stash_ref_parse_failed" }
Write-Host "STASH_REF=$stashRef"

$untrackedCommitOutput = & git -C $RepoRoot rev-parse "$stashRef^3" 2>&1
if ($LASTEXITCODE -ne 0) { Fail "stash_untracked_parent_missing ref=$stashRef" }
$untrackedCommit = ($untrackedCommitOutput | Select-Object -First 1).Trim()
Write-Host "STASH_UNTRACKED_COMMIT=$untrackedCommit"

foreach ($path in $ExpectedPaths) {
    & git -C $RepoRoot cat-file -e "${untrackedCommit}:$path" 2>$null
    if ($LASTEXITCODE -ne 0) { Fail "stash_path_missing=$path" }
    Write-Host "STASH_PATH=PASS $path"
}

$tempRoot = Join-Path $env:TEMP ("taijifu-c63-2-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $tempRoot "character-lock.zip"
$extractRoot = Join-Path $tempRoot "extracted"
$worktree = Join-Path $tempRoot "worktree"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    $archiveArgs = @("archive", "--format=zip", "--output=$archivePath", $untrackedCommit, "--") + $ExpectedPaths
    Invoke-RepoGit $archiveArgs | Out-Null
    if (-not (Test-Path $archivePath)) { Fail "stash_archive_missing" }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force

    foreach ($entry in $Expected.GetEnumerator()) {
        $source = Join-Path $extractRoot ($entry.Key -replace "/", "\")
        if (-not (Test-Path $source)) { Fail "extracted_path_missing=$($entry.Key)" }
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
        if ($actual -ne $entry.Value) { Fail "historical_hash_mismatch=$($entry.Key) expected=$($entry.Value) actual=$actual" }
        Assert-Png1024Rgba $source $entry.Key
        Write-Host "EXACT_SHA256=PASS $($entry.Key) $actual"
        Write-Host "PNG_1024_RGBA=PASS $($entry.Key)"
    }

    $refspec = "+refs/heads/$Branch`:refs/remotes/origin/$Branch"
    Invoke-RepoGit @("fetch", "origin", $refspec) | Out-Null
    $remoteRef = "origin/$Branch"
    & git -C $RepoRoot rev-parse --verify $remoteRef *> $null
    if ($LASTEXITCODE -ne 0) { Fail "remote_recovery_branch_missing=$Branch" }

    $worktreeOutput = & git -C $RepoRoot worktree add --detach $worktree $remoteRef 2>&1
    if ($LASTEXITCODE -ne 0) { Fail ("worktree_add_failed=" + ($worktreeOutput -join " | ")) }

    foreach ($entry in $Expected.GetEnumerator()) {
        $source = Join-Path $extractRoot ($entry.Key -replace "/", "\")
        $target = Join-Path $worktree ($entry.Key -replace "/", "\")
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
        if ($actual -ne $entry.Value) { Fail "copy_hash_mismatch=$($entry.Key)" }
    }

    $changed = @(& git -C $worktree status --short)
    $unexpected = @($changed | Where-Object {
        $line = $_.Trim()
        -not ($line.EndsWith("assets/characters/lian_wu/character_lock/lian_wu_neutral.png") -or
              $line.EndsWith("assets/characters/lian_wu/character_lock/lian_wu_combat_stance.png"))
    })
    if ($unexpected.Count -gt 0) { Fail ("unexpected_worktree_changes=" + ($unexpected -join ",")) }

    & git -C $worktree add -- @ExpectedPaths
    if ($LASTEXITCODE -ne 0) { Fail "git_add_failed" }
    $staged = @(& git -C $worktree diff --cached --name-only)
    if ($staged.Count -ne 2) { Fail ("staged_file_count=" + $staged.Count) }
    foreach ($path in $ExpectedPaths) {
        if ($staged -notcontains $path) { Fail "staged_path_missing=$path" }
    }

    $userName = (& git -C $worktree config user.name 2>$null)
    if (-not $userName) { & git -C $worktree config user.name "Tehkné Solutions" }
    $userEmail = (& git -C $worktree config user.email 2>$null)
    if (-not $userEmail) { & git -C $worktree config user.email "master-taijifu@tehkne.com" }

    & git -C $worktree commit -m "fix(c63.2): recover exact canonical Lian Wu Character Lock bytes"
    if ($LASTEXITCODE -ne 0) { Fail "git_commit_failed" }
    $head = (& git -C $worktree rev-parse HEAD).Trim()

    & git -C $worktree push origin "HEAD:refs/heads/$Branch"
    if ($LASTEXITCODE -ne 0) { Fail "git_push_failed" }

    Write-Host ""
    Write-Host "C63_2_EXACT_RECOVERY=PASS" -ForegroundColor Green
    Write-Host "BRANCH=$Branch"
    Write-Host "HEAD=$head"
    Write-Host "FILES=2"
    Write-Host "STASH_MUTATED=NO"
    Write-Host "PRIMARY_WORKTREE_MUTATED=NO"
    Write-Host "NEXT=REMOTE_C63_2_SHA_GODOT_GATE"
    Write-Host "SIGNATURE=Tehkné Solutions"
}
finally {
    if (Test-Path $worktree) {
        & git -C $RepoRoot worktree remove --force $worktree *> $null
    }
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
