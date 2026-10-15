# Prepared for review; not executed against GitHub. Windows PowerShell 5.1+.
# A normal invocation publishes. -CheckOnly performs validation/read-only queries.
[CmdletBinding()]
param(
    [string]$SourceRoot = '',
    [string]$DeliverablesRoot = '',
    [string]$ChecksumFile = 'SHA256SUMS-v0.3.txt',
    [string]$ReviewFile = 'AsteraCraft-v0.3-review.md',
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = 'INTPEDITOR/asteracraft-releases'
$tag = 'v0.3'
$releaseTitle = 'AsteraCraft v0.3 - Windows prototype and Godot source'
$script:GhExecutable = ''

function Invoke-GhCapture([string[]]$Arguments) {
    # Capture all native output, including auth diagnostics. Never echo tokens,
    # environment variables, raw auth output or arbitrary API failure responses.
    $previousPreference = $ErrorActionPreference
    $previousConsoleEncoding = [Console]::OutputEncoding
    try {
        $ErrorActionPreference = 'Continue'
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $lines = @(& $script:GhExecutable @Arguments 2>&1)
        $nativeExitCode = $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $previousConsoleEncoding
        $ErrorActionPreference = $previousPreference
    }
    return [pscustomobject]@{ Code = $nativeExitCode; Text = ($lines -join "`n") }
}

function Assert-GhSuccess($Result, [string]$Operation) {
    if ($Result.Code -ne 0) {
        throw "$Operation failed (GitHub CLI exit $($Result.Code)). Check GitHub access, authentication and repository permissions. No error output or credentials were printed."
    }
}

function Read-GitHubObject([string]$Endpoint, [switch]$AllowMissing) {
    $result = Invoke-GhCapture -Arguments @('api', '--hostname', 'github.com', $Endpoint)
    if ($result.Code -eq 0) {
        try { return ($result.Text | ConvertFrom-Json) }
        catch { throw "GitHub returned an invalid JSON response for $Endpoint." }
    }
    # Never treat DNS, rate limits, 401 or 403 as 'repository/release absent'.
    if ($AllowMissing -and $result.Text -match '\(HTTP 404\)') { return $null }
    Assert-GhSuccess $result "Reading $Endpoint"
}

function Resolve-ReleaseFile([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or
        [IO.Path]::GetFileName($Name) -cne $Name -or
        $Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Release filenames must be plain ASCII leaf names: $Name"
    }
    $candidate = [IO.Path]::GetFullPath((Join-Path $script:ReleaseDirectory $Name))
    if (-not $candidate.StartsWith($script:ReleaseDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Release path escaped deliverables: $Name"
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Required v0.3 file is missing: $candidate. Finish packaging first; an older build will not be substituted."
    }
    $item = Get-Item -LiteralPath $candidate -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $item.Length -le 0) {
        throw "Release files must be non-empty regular files: $candidate"
    }
    return $candidate
}

function Assert-LocalAsset($Asset) {
    $item = Get-Item -LiteralPath $Asset.Path -Force
    $hash = (Get-FileHash -LiteralPath $Asset.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($item.Length -ne $Asset.Bytes -or $hash -cne $Asset.SHA256) {
        throw "A release file changed after verification: $($Asset.Name). Rebuild SHA256SUMS before publishing."
    }
}

function Normalize-Notes([string]$Text) {
    return $Text.Replace("`r`n", "`n").TrimEnd()
}

function Find-Release {
    # The tag endpoint is documented for published releases. Listing as the
    # authenticated owner also finds a previous unfinished draft safely.
    $pageNumber = 1
    $matching = @()
    do {
        $batch = @(Read-GitHubObject "repos/$repository/releases?per_page=100&page=$pageNumber" | Where-Object { $null -ne $_ })
        $matching += @($batch | Where-Object { $_.tag_name -ceq $tag })
        $pageNumber++
    } while ($batch.Count -eq 100)
    if ($matching.Count -gt 1) { throw 'Multiple releases/drafts use v0.3. Resolve the ambiguity manually; no release was selected.' }
    if ($matching.Count -eq 1) { return $matching[0] }
    return $null
}

function Assert-ReleaseNotes($Release) {
    if ($Release.tag_name -cne $tag -or $Release.name -cne $releaseTitle -or -not $Release.prerelease -or
        (Normalize-Notes ([string]$Release.body)) -cne (Normalize-Notes $notes)) {
        throw 'Existing v0.3 tag/title/notes/prerelease status differ. They were not edited. Inspect the release and publish changed builds under a new tag.'
    }
}

function Assert-ReleaseAssetNames($Release) {
    $seenNames = @{}
    foreach ($remote in $Release.assets) {
        if ($remote.name -notin @($assets.Name) -or $seenNames.ContainsKey([string]$remote.name)) {
            throw 'The release has unexpected or duplicate attachments. No attachments were deleted or overwritten; inspect the release manually.'
        }
        $seenNames[[string]$remote.name] = $true
    }
    if (-not $Release.draft -and $seenNames.Count -ne $assets.Count) {
        throw 'An already published release is incomplete. It was not changed; inspect it manually or use a new tag.'
    }
}

function Save-GitHubAsset([long]$AssetId, [string]$Destination) {
    # Read the fixed asset ID. Native stdout bytes avoid PowerShell 5.1's text
    # redirection corrupting ZIP downloads. No auth token is read or printed.
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $script:GhExecutable
    $startInfo.Arguments = 'api --hostname github.com --header "Accept: application/octet-stream" repos/' + $repository + '/releases/assets/' + $AssetId
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $destinationStream = $null
    try {
        if (-not $process.Start()) { throw 'Unable to start GitHub asset verification.' }
        $discardedDiagnostics = $process.StandardError.ReadToEndAsync()
        $destinationStream = [IO.File]::Create($Destination)
        $process.StandardOutput.BaseStream.CopyTo($destinationStream)
        $destinationStream.Dispose()
        $destinationStream = $null
        $process.WaitForExit()
        $discardedDiagnostics.GetAwaiter().GetResult() | Out-Null
        if ($process.ExitCode -ne 0) { throw 'Downloading an existing asset by ID failed. No credentials or server diagnostics were printed.' }
    } finally {
        if ($null -ne $destinationStream) { $destinationStream.Dispose() }
        $process.Dispose()
    }
}

function Assert-RemoteAsset($Remote, $Local) {
    if ([long]$Remote.size -ne $Local.Bytes) {
        throw "Existing GitHub asset differs in size: $($Local.Name). Nothing is overwritten; use a new release tag for a changed build."
    }
    $digestProperty = $Remote.PSObject.Properties['digest']
    if ($null -ne $digestProperty -and [string]$digestProperty.Value -match '^sha256:([a-fA-F0-9]{64})$') {
        if ($Matches[1].ToLowerInvariant() -cne $Local.SHA256) {
            throw "Existing GitHub asset has a different SHA256: $($Local.Name). Nothing is overwritten; use a new release tag."
        }
        return
    }
    # Older assets may not expose a server digest. Download into this run's
    # isolated directory and compare actual bytes rather than trusting a name.
    $verifyDirectory = Join-Path $script:TaskDirectory ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $verifyDirectory | Out-Null
    $download = Join-Path $verifyDirectory $Local.Name
    Save-GitHubAsset ([long]$Remote.id) $download
    if (-not (Test-Path -LiteralPath $download -PathType Leaf) -or
        (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Local.SHA256) {
        throw "Existing GitHub asset has different bytes: $($Local.Name). No overwrite was attempted."
    }
}

# SourceRoot accepts either the workspace/migration root or project directory.
# Both C:\...\new-chat-5 and E:\Codex\AsteraCraft contain AsteraCraft\project.godot.
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Join-Path $PSScriptRoot '..\..' }
$resolvedSource = (Resolve-Path -LiteralPath $SourceRoot).ProviderPath.TrimEnd('\', '/')
if (Test-Path -LiteralPath (Join-Path $resolvedSource 'AsteraCraft\project.godot') -PathType Leaf) {
    $workspaceDirectory = $resolvedSource
    $projectDirectory = Join-Path $resolvedSource 'AsteraCraft'
} elseif (Test-Path -LiteralPath (Join-Path $resolvedSource 'project.godot') -PathType Leaf) {
    $projectDirectory = $resolvedSource
    $workspaceDirectory = Split-Path -Parent $resolvedSource
} else { throw 'SourceRoot must contain AsteraCraft\project.godot, or be the Godot project directory itself.' }
if ([string]::IsNullOrWhiteSpace($DeliverablesRoot)) { $DeliverablesRoot = Join-Path $workspaceDirectory 'deliverables' }
if (-not (Test-Path -LiteralPath $DeliverablesRoot -PathType Container)) { throw "Missing deliverables directory: $DeliverablesRoot" }
$script:ReleaseDirectory = (Resolve-Path -LiteralPath $DeliverablesRoot).ProviderPath.TrimEnd('\', '/')

$windowsName = 'AsteraCraft-Windows-v0.3.zip'
$sourceName = 'AsteraCraft-Godot-v0.3.zip'
$windowsPath = Resolve-ReleaseFile $windowsName
$sourcePath = Resolve-ReleaseFile $sourceName
$checksumPath = Resolve-ReleaseFile $ChecksumFile
$reviewPath = Resolve-ReleaseFile $ReviewFile
if ($ChecksumFile -eq $ReviewFile -or $ChecksumFile -in @($windowsName, $sourceName) -or $ReviewFile -in @($windowsName, $sourceName)) {
    throw 'The two ZIPs, checksum manifest and review must be four distinct files.'
}

$checksumRaw = [IO.File]::ReadAllBytes($checksumPath)
$checksumAlgorithm = [Security.Cryptography.SHA256]::Create()
try { $checksumHash = ([BitConverter]::ToString($checksumAlgorithm.ComputeHash($checksumRaw))).Replace('-', '').ToLowerInvariant() }
finally { $checksumAlgorithm.Dispose() }
$checksumText = [Text.Encoding]::UTF8.GetString($checksumRaw).TrimStart([char]0xFEFF)
$expectedHashes = @{}
foreach ($line in $checksumText -split '\r?\n') {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) { continue }
    if ($line -notmatch '^(?<hash>[a-fA-F0-9]{64})[ \t]+\*?(?<name>[^\r\n]+?)\s*$') {
        throw 'Invalid SHA256SUMS line. Expected: 64 hexadecimal characters, two spaces, plain filename.'
    }
    $name = $Matches['name']
    $expectedHash = $Matches['hash'].ToLowerInvariant()
    if ($expectedHashes.ContainsKey($name)) { throw "Duplicate filename in SHA256SUMS: $name" }
    if ($name.Equals($ChecksumFile, [StringComparison]::OrdinalIgnoreCase)) { throw 'SHA256SUMS cannot contain its own checksum.' }
    $listedFile = Resolve-ReleaseFile $name
    $actualHash = (Get-FileHash -LiteralPath $listedFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne $expectedHash) { throw "SHA256 mismatch: $name. No GitHub changes were made." }
    $expectedHashes[$name] = $expectedHash
}
foreach ($name in @($windowsName, $sourceName, $ReviewFile)) {
    if (-not $expectedHashes.ContainsKey($name)) { throw "SHA256SUMS must include this release payload: $name" }
}
$assets = @()
foreach ($path in @($windowsPath, $sourcePath, $checksumPath, $reviewPath)) {
    $item = Get-Item -LiteralPath $path
    $expectedHash = $checksumHash
    if (-not $item.Name.Equals($ChecksumFile, [StringComparison]::OrdinalIgnoreCase)) { $expectedHash = $expectedHashes[$item.Name] }
    $asset = [pscustomobject]@{ Name = $item.Name; Path = $item.FullName; Bytes = [long]$item.Length; SHA256 = $expectedHash }
    Assert-LocalAsset $asset
    $assets += $asset
}

$ghCommand = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $ghCommand) {
    throw 'GitHub CLI is not installed. Install it with: winget install --id GitHub.cli --exact . Open a new PowerShell, then run: gh auth login --hostname github.com --web --git-protocol https . Sign in as INTPEDITOR; rerun this script. Do not paste or print a token.'
}
$script:GhExecutable = $ghCommand.Source
$savedGhHost = [Environment]::GetEnvironmentVariable('GH_HOST', 'Process')
$savedGhPrompt = [Environment]::GetEnvironmentVariable('GH_PROMPT_DISABLED', 'Process')
$script:TaskDirectory = ''
try {
    $env:GH_HOST = 'github.com'
    $env:GH_PROMPT_DISABLED = '1'
    $auth = Invoke-GhCapture -Arguments @('auth', 'status', '--hostname', 'github.com')
    if ($auth.Code -ne 0) {
        throw 'GitHub CLI is not logged in. Run: gh auth login --hostname github.com --web --git-protocol https . Sign in as INTPEDITOR, then rerun. No token is needed in this script.'
    }
    $identity = Invoke-GhCapture -Arguments @('api', '--hostname', 'github.com', 'user', '--jq', '.login')
    Assert-GhSuccess $identity 'Verifying the GitHub account'
    if (-not $identity.Text.Trim().Equals('INTPEDITOR', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The active GitHub account is not INTPEDITOR. Run: gh auth switch --hostname github.com --user INTPEDITOR . No other account or repository will be modified.'
    }
    $repo = Read-GitHubObject "repos/$repository" -AllowMissing
    if ($null -ne $repo -and ($repo.full_name -ine $repository -or $repo.private -or $repo.archived -or $repo.fork)) {
        throw 'The dedicated target must be the public, non-archived, non-fork INTPEDITOR/asteracraft-releases repository. Its visibility/settings will not be changed automatically.'
    }

    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $script:TaskDirectory = [IO.Path]::GetFullPath((Join-Path $tempRoot ('AsteraCraft-Publish-' + [Guid]::NewGuid().ToString('N'))))
    New-Item -ItemType Directory -Path $script:TaskDirectory | Out-Null
    $notesFile = Join-Path $script:TaskDirectory 'release-notes-v0.3.md'
    $notes = @'
AsteraCraft v0.3 is a playable Windows prototype with a Godot 4.6 source archive.

Download AsteraCraft-Windows-v0.3.zip, extract every file, and run AsteraCraft.exe.
Keep the PCK, runtime and server folders with the executable. Windows x64 and
OpenGL 3.3 are required. Godot and Node.js do not need a separate player install.
For the game project, use AsteraCraft-Godot-v0.3.zip, not GitHub's automatic
"Source code" archive (this dedicated release repository holds no project history).

Implemented scope includes three factions, 13 unit and building types per faction,
single-player bots, custom/ladder systems, generated artwork, resource collection,
unit collision, and improvements to menus, HUD, animation and movement.

Known limits and remaining verification:
- Automatic multiplayer discovery covers the same LAN. No operational public
  Internet lobby is included. Public service requires a deployed lobby, HTTPS,
  PUBLIC_HOST and reachable battle UDP ports. Two-PC ENet matches, router-specific
  discovery, latency and sustained reconnect behavior remain unverified; local
  socket access was blocked in the build environment. API tests are not proof of
  a successful real network match.
- The Fighting Spirit-inspired battlefield is a reconstruction. Original SCX/CHK
  terrain, collision, distances, resources and balance were not fully compared
  (exact_source=false; collision_verified_against_original=false). Other maps and
  faction win rates/build timings still require playtesting.
- New motion sheets use nine stored directions and 16 mirrored directions,
  including aircraft. Older 32-direction aircraft idle art is auxiliary.
  Generated short loops still need per-direction equipment/foot/death cleanup.
- Campaigns, single-player save/load, command-replay simulation, music and voice
  acting are not included. Replay currently records the player's view state at
  one-second intervals and plays it at approximately twice normal speed.
- Benchmarks are short headless debug comparisons. The 400-unit dense combat
  case averaged 49.134 ms/tick, p95 66.972 ms; some ticks exceed the 50 ms budget.
  Results do not guarantee steady frame rates on all hardware.

Verified release file SHA256 values:
'@
    foreach ($asset in $assets) { $notes += "`n$($asset.SHA256)  $($asset.Name)" }
    $notes += "`n`nBuild review (also attached as $ReviewFile):`n`n" + (Get-Content -LiteralPath $reviewPath -Raw -Encoding UTF8)
    $notes = (Normalize-Notes $notes) + "`n"
    [IO.File]::WriteAllText($notesFile, $notes, [Text.UTF8Encoding]::new($false))
    Write-Output "Verified four v0.3 release files. Target: https://github.com/$repository/releases/tag/$tag"

    $release = $null
    if ($null -ne $repo) { $release = Find-Release }
    if ($null -ne $release) {
        Assert-ReleaseNotes $release
        Assert-ReleaseAssetNames $release
        foreach ($asset in $assets) {
            $sameName = @($release.assets | Where-Object { $_.name -ieq $asset.Name })
            if ($sameName.Count -gt 1) { throw "Duplicate remote asset names: $($asset.Name)" }
            if ($sameName.Count -eq 1) { Assert-RemoteAsset $sameName[0] $asset }
        }
    }
    foreach ($asset in $assets) { Assert-LocalAsset $asset }
    if ($CheckOnly) {
        Write-Output 'CHECK ONLY: no GitHub changes. Missing dedicated repository/release/assets would be created by a normal invocation.'
        return
    }
    if ($null -eq $repo) {
        $created = Invoke-GhCapture -Arguments @('repo', 'create', $repository, '--public', '--add-readme', '--disable-issues', '--disable-wiki', '--description', 'AsteraCraft Windows prototype and Godot source releases')
        Assert-GhSuccess $created 'Creating the dedicated AsteraCraft release repository'
    }
    if ($null -eq $release) {
        $created = Invoke-GhCapture -Arguments @('release', 'create', $tag, '--repo', $repository, '--title', $releaseTitle, '--notes-file', $notesFile, '--draft', '--prerelease')
        Assert-GhSuccess $created 'Creating the v0.3 draft release'
        $release = Find-Release
        if ($null -eq $release) { throw 'The new draft could not be found. No publication was attempted; inspect the dedicated repository and rerun.' }
    }
    $releaseId = [long]$release.id
    foreach ($asset in $assets) {
        Assert-LocalAsset $asset
        # Refresh before each upload: a concurrent publisher cannot cause clobber.
        $release = Read-GitHubObject "repos/$repository/releases/$releaseId"
        Assert-ReleaseNotes $release
        Assert-ReleaseAssetNames $release
        $sameName = @($release.assets | Where-Object { $_.name -ieq $asset.Name })
        if ($sameName.Count -gt 1) { throw "Duplicate remote asset names: $($asset.Name)" }
        if ($sameName.Count -eq 1) {
            Assert-RemoteAsset $sameName[0] $asset
            Write-Output "Already uploaded with matching SHA256: $($asset.Name)"
            continue
        }
        $uploadUrl = 'https://uploads.github.com/repos/' + $repository + '/releases/' + $releaseId + '/assets?name=' + [Uri]::EscapeDataString($asset.Name)
        $uploaded = Invoke-GhCapture -Arguments @('api', '--hostname', 'github.com', '--method', 'POST', $uploadUrl, '--header', 'Content-Type: application/octet-stream', '--input', $asset.Path)
        Assert-GhSuccess $uploaded "Uploading $($asset.Name)"
    }
    $release = Read-GitHubObject "repos/$repository/releases/$releaseId"
    Assert-ReleaseNotes $release
    Assert-ReleaseAssetNames $release
    foreach ($asset in $assets) {
        Assert-LocalAsset $asset
        $remote = @($release.assets | Where-Object { $_.name -ieq $asset.Name })
        if ($remote.Count -ne 1) { throw "Upload verification failed: $($asset.Name). A new draft was left unpublished for inspection." }
        Assert-RemoteAsset $remote[0] $asset
    }
    if ($release.draft) {
        $publishBody = Join-Path $script:TaskDirectory 'publish-v0.3.json'
        [IO.File]::WriteAllText($publishBody, '{"draft":false}', [Text.UTF8Encoding]::new($false))
        $published = Invoke-GhCapture -Arguments @('api', '--hostname', 'github.com', '--method', 'PATCH', "repos/$repository/releases/$releaseId", '--input', $publishBody)
        Assert-GhSuccess $published 'Publishing the verified v0.3 prerelease'
    }
    $release = Read-GitHubObject "repos/$repository/releases/$releaseId"
    Assert-ReleaseNotes $release
    Assert-ReleaseAssetNames $release
    if ($release.draft) { throw 'GitHub still reports a draft. The verified files remain attached; inspect the release before retrying publication.' }
    Write-Output "Published and verified: https://github.com/$repository/releases/tag/$tag"
} finally {
    [Environment]::SetEnvironmentVariable('GH_HOST', $savedGhHost, 'Process')
    [Environment]::SetEnvironmentVariable('GH_PROMPT_DISABLED', $savedGhPrompt, 'Process')
    if (-not [string]::IsNullOrEmpty($script:TaskDirectory) -and (Test-Path -LiteralPath $script:TaskDirectory)) {
        # Resolve and constrain the complete absolute recursive-delete target.
        $resolvedTemporary = (Resolve-Path -LiteralPath $script:TaskDirectory).ProviderPath.TrimEnd('\', '/')
        $expectedTemporary = [IO.Path]::GetFullPath($script:TaskDirectory).TrimEnd('\', '/')
        $actualParent = [IO.Path]::GetFullPath((Split-Path -Parent $resolvedTemporary)).TrimEnd('\', '/')
        if ($resolvedTemporary.Equals($expectedTemporary, [StringComparison]::OrdinalIgnoreCase) -and
            $actualParent.Equals($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedTemporary) -match '^AsteraCraft-Publish-[a-f0-9]{32}$') {
            try { Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force }
            catch { Write-Warning 'Temporary verification files could not be removed; release status is unaffected.' }
        } else { Write-Warning 'Temporary verification folder failed the cleanup boundary check and was retained.' }
    }
}
