# This script is prepared for review. It has not been run against E:.
# Default: print a plan only. -Copy copies and verifies. -Copy -DeleteSource
# additionally removes only allowlisted original entries after verification.
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$SourceRoot = '',
    [string]$DestinationRoot = 'E:\Codex\AsteraCraft',
    [switch]$Copy,
    [switch]$DeleteSource
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).ProviderPath.TrimEnd('\')
$DestinationRoot = [IO.Path]::GetFullPath($DestinationRoot).TrimEnd('\')
$expectedDestination = [IO.Path]::GetFullPath('E:\Codex\AsteraCraft').TrimEnd('\')

if (-not $DestinationRoot.Equals($expectedDestination, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must be the explicitly named E:\Codex\AsteraCraft directory.'
}
if ($SourceRoot.Equals($DestinationRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $DestinationRoot.StartsWith($SourceRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $SourceRoot.StartsWith($DestinationRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Source and destination must be separate, non-nested directories.'
}
if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot 'AsteraCraft\project.godot') -PathType Leaf)) {
    throw 'SourceRoot must be the workspace parent containing AsteraCraft\project.godot.'
}
if ($DeleteSource -and -not $Copy) {
    throw 'Deletion is available only with -Copy -DeleteSource after SHA256 verification.'
}

# Explicit game/material allowlist. Unrelated folders such as NVIDIA Corporation,
# configuration/transport helper folders, data outside these roots and other
# projects are never selected. Local game data inside AsteraCraft is preserved
# during migration; this is separate from public-release packaging exclusions.
$allowlist = @(
    'AsteraCraft',
    'deliverables',
    'tools',
    'rts-references',
    'outputs',
    'work',
    'audit_source_sprites.js',
    'inspect_motion.js',
    'motion_check.gd'
)

function Assert-WithinRoot([string]$Candidate, [string]$RootPath) {
    $absolute = [IO.Path]::GetFullPath($Candidate).TrimEnd('\')
    if (-not $absolute.StartsWith($RootPath.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escaped the named root: $absolute"
    }
    return $absolute
}

function Assert-NoReparseAncestors([string]$Candidate) {
    $cursor = [IO.Path]::GetFullPath($Candidate)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Junction/symbolic-link ancestor is not allowed: $cursor"
            }
        }
        $parentInfo = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parentInfo) { break }
        $parent = $parentInfo.FullName
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-GameManifest([bool]$CalculateHash) {
    $records = [Collections.Generic.List[object]]::new()
    $directories = [Collections.Generic.List[string]]::new()
    foreach ($entry in $allowlist) {
        $entryPath = Assert-WithinRoot (Join-Path $SourceRoot $entry) $SourceRoot
        if (-not (Test-Path -LiteralPath $entryPath)) { continue }
        $item = Get-Item -LiteralPath $entryPath -Force
        $items = @($item)
        if ($item.PSIsContainer) { $items += @(Get-ChildItem -LiteralPath $entryPath -Force -Recurse) }
        foreach ($child in $items) {
            $absolute = Assert-WithinRoot $child.FullName $SourceRoot
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Junction/symbolic link is not allowed in the migration set: $absolute"
            }
            $relative = $absolute.Substring($SourceRoot.Length + 1)
            if ($child.PSIsContainer) {
                $directories.Add($relative)
            } else {
                $hash = ''
                if ($CalculateHash) { $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash }
                $records.Add([pscustomobject]@{ Path = $relative; Bytes = [long]$child.Length; SHA256 = $hash })
            }
        }
    }
    return [pscustomobject]@{
        Files = @($records.ToArray() | Sort-Object Path)
        Directories = @($directories.ToArray() | Sort-Object -Unique)
    }
}

function Assert-SameManifest($Before, $After) {
    if ($Before.Files.Count -ne $After.Files.Count) { throw 'Source file count changed during migration; deletion is stopped.' }
    for ($index = 0; $index -lt $Before.Files.Count; $index++) {
        $first = $Before.Files[$index]
        $second = $After.Files[$index]
        if ($first.Path -cne $second.Path -or $first.Bytes -ne $second.Bytes -or $first.SHA256 -cne $second.SHA256) {
            throw "Source changed during migration; deletion is stopped: $($first.Path)"
        }
    }
    if (($Before.Directories -join "`n") -cne ($After.Directories -join "`n")) { throw 'Source directory set changed during migration; deletion is stopped.' }
}

function Assert-DestinationFiles($Manifest) {
    foreach ($record in $Manifest.Files) {
        $target = Assert-WithinRoot (Join-Path $DestinationRoot $record.Path) $DestinationRoot
        Assert-NoReparseAncestors $target
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing destination file: $target" }
        $copied = Get-Item -LiteralPath $target -Force
        if ($copied.Length -ne $record.Bytes -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne $record.SHA256) {
            throw "Destination checksum differs; deletion is stopped: $target"
        }
    }
}

Assert-NoReparseAncestors $SourceRoot
$plan = Get-GameManifest $false
$bytes = [long]0
foreach ($file in $plan.Files) { $bytes += $file.Bytes }
Write-Output "Source: $SourceRoot"
Write-Output "Destination: $DestinationRoot"
Write-Output ("Plan: {0} files, {1} directories, {2:N2} GiB" -f $plan.Files.Count, $plan.Directories.Count, ($bytes / 1GB))
Write-Output ('Allowed entries: ' + ($allowlist -join ', '))

if (-not $Copy) {
    Write-Output 'DRY RUN. No destination writes and no source deletion. Close the game, Godot and local lobby before any real migration.'
    Write-Output 'Use -Copy to copy and verify; use -Copy -DeleteSource to also delete verified allowlisted originals.'
    return
}
if (-not $PSCmdlet.ShouldProcess($DestinationRoot, 'Copy allowlisted game/material files and verify SHA256')) { return }

Assert-NoReparseAncestors $DestinationRoot
$baseline = Get-GameManifest $true
New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
foreach ($directory in $baseline.Directories) {
    $targetDirectory = Assert-WithinRoot (Join-Path $DestinationRoot $directory) $DestinationRoot
    Assert-NoReparseAncestors $targetDirectory
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
}
foreach ($record in $baseline.Files) {
    $source = Assert-WithinRoot (Join-Path $SourceRoot $record.Path) $SourceRoot
    $target = Assert-WithinRoot (Join-Path $DestinationRoot $record.Path) $DestinationRoot
    Assert-NoReparseAncestors $target
    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
            (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne $record.SHA256) {
            throw "A different destination file already exists; no overwrite or deletion was performed: $target"
        }
        continue
    }
    Copy-Item -LiteralPath $source -Destination $target -ErrorAction Stop
}
Assert-DestinationFiles $baseline
Assert-SameManifest $baseline (Get-GameManifest $true)

$manifestName = 'migration-manifest-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '.json'
$manifestPath = Assert-WithinRoot (Join-Path $DestinationRoot $manifestName) $DestinationRoot
[pscustomobject]@{
    Source = $SourceRoot
    Destination = $DestinationRoot
    VerifiedUtc = [DateTime]::UtcNow.ToString('o')
    Allowlist = $allowlist
    Directories = $baseline.Directories
    Files = $baseline.Files
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Output "Verified SHA256 for all $($baseline.Files.Count) files. Manifest: $manifestPath"

if (-not $DeleteSource) {
    Write-Output 'Copy complete. All source files were retained.'
    return
}

# Recheck every file and every resolved removal target immediately before deleting.
Assert-DestinationFiles $baseline
Assert-SameManifest $baseline (Get-GameManifest $true)
$removeTargets = @()
foreach ($entry in $allowlist) {
    $target = Assert-WithinRoot (Join-Path $SourceRoot $entry) $SourceRoot
    if (-not (Test-Path -LiteralPath $target)) { continue }
    $resolved = (Resolve-Path -LiteralPath $target).ProviderPath.TrimEnd('\')
    if (-not $resolved.Equals($target, [StringComparison]::OrdinalIgnoreCase)) { throw "Removal target changed: $target" }
    Assert-NoReparseAncestors $resolved
    $removeTargets += $resolved
}
if ($PSCmdlet.ShouldProcess(($removeTargets -join '; '), 'Delete only SHA256-verified allowlisted source entries')) {
    foreach ($target in $removeTargets) {
        # Native PowerShell only; no cmd/batch or string-built delete commands.
        if ((Get-Item -LiteralPath $target -Force).PSIsContainer) {
            Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
        } else {
            Remove-Item -LiteralPath $target -Force -ErrorAction Stop
        }
    }
    Write-Output 'Verified source entries removed. Unrelated workspace entries were retained.'
}
