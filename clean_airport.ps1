#requires -Version 5.1
<#
Deletes metadata beneath this script's own directory. No alternate root argument.
Examples: clean_airport.bat -Preview
          clean_airport.bat
          clean_airport.bat -IncludeTrash -IncludeLegacyAperture
Reparse points (junctions, symlinks, mount points, etc.) are never traversed or deleted.
Run on a quiescent tree: path checks cannot protect against another process swapping
directories for links between a check and a filesystem operation.
#>
[CmdletBinding()]
param(
    [switch]$Preview,
    [switch]$IncludeTrash,
    [switch]$IncludeLegacyAperture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($PSScriptRoot)
$prefix = $root.TrimEnd('\') + '\'
$stats = @{ Files = 0; Folders = 0; Links = 0; Errors = 0 }

# Exact names, compared case-insensitively. Do not use *.encryptable or *Trash*.
$fileNames = @('.DS_Store', '.apDisk', 'desktop.ini', 'Thumbs.db',
    'Thumbs.db.encryptable', 'ehthumbs.db', 'ehthumbs_vista.db')
$folderNames = @('.Spotlight-V100', '.fseventsd', '.TemporaryItems', '.AppleDouble')
if ($IncludeTrash) { $folderNames += @('.Trash', '.Trashes') }

function Assert-SafePath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not ($full.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
        $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
        throw "Outside cleanup root: $Path"
    }
    # Check every ancestor, including those ABOVE the cleanup root. Refuse a root
    # reached through a junction as well as links discovered inside the tree.
    $probe = $full
    while ($probe) {
        $attrs = [IO.File]::GetAttributes($probe)
        if (($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point in path: $probe"
        }
        $parent = [IO.Directory]::GetParent($probe)
        if ($null -eq $parent) { break }
        $probe = $parent.FullName
    }
}

function Report-Failure([string]$Path, $Failure) {
    $stats.Errors++
    Write-Warning ("Skipped {0}: {1}" -f $Path, $Failure.Exception.Message)
}

function Remove-MetadataFile([string]$Path) {
    Assert-SafePath $Path
    if ($Preview) {
        Write-Output "WOULD DELETE FILE: $Path"
    } else {
        # LiteralPath protects names containing wildcard characters such as [ ].
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        Write-Output "DELETED FILE: $Path"
    }
    $stats.Files++
}

try { Assert-SafePath $root } catch {
    Write-Warning ("Cannot safely use cleanup root: {0}" -f $_.Exception.Message)
    exit 1
}

Write-Output "Cleanup root: $root"
if ($Preview) { Write-Output 'PREVIEW ONLY - no changes will be made.' }
else { Write-Output 'Cleanup mode - matching files are permanently deleted.' }

# An explicit stack avoids recursive traversal commands that could follow links.
# Exit frames remove only empty directories; there is NO recursive folder delete.
$stack = New-Object 'System.Collections.Generic.Stack[object]'
$stack.Push(@{ Path = $root; Purge = $false; Exit = $false })
while ($stack.Count -gt 0) {
    $frame = $stack.Pop()
    $path = [string]$frame.Path
    try {
        Assert-SafePath $path
        if ($frame.Exit) {
            if ($Preview) {
                Write-Output "WOULD REMOVE FOLDER IF EMPTY AFTER CLEANUP: $path"
                $stats.Folders++
            } else {
                # Directory.Delete(false) fails safely if a skipped link, locked
                # file, or newly created file remains. Never fall back to recursion.
                [IO.Directory]::Delete($path, $false)
                Write-Output "DELETED FOLDER: $path"
                $stats.Folders++
            }
            continue
        }
        $children = @(Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop)
        if ($frame.Purge) {
            $stack.Push(@{ Path = $path; Purge = $true; Exit = $true })
        }
        foreach ($child in $children) {
            try {
                if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $stats.Links++
                    Write-Output "SKIPPED LINK / REPARSE POINT: $($child.FullName)"
                    continue
                }
                if ($child.PSIsContainer) {
                    # Trash contents remain entirely untouched unless requested.
                    if (-not $IncludeTrash -and $child.Name -in @('.Trash', '.Trashes')) { continue }
                    $purge = $frame.Purge -or ($child.Name -in $folderNames)
                    $stack.Push(@{ Path = $child.FullName; Purge = $purge; Exit = $false })
                } else {
                    $matches = ($child.Name -in $fileNames) -or ($child.Name -like '._*')
                    if ($IncludeLegacyAperture) {
                        $matches = $matches -or ($child.Name -ieq 'Master.apmaster') -or
                            ($child.Name -like '*.apversion')
                    }
                    if ($frame.Purge -or $matches) { Remove-MetadataFile $child.FullName }
                }
            } catch { Report-Failure $child.FullName $_ }
        }
    } catch { Report-Failure $path $_ }
}

$label = 'Deleted'
if ($Preview) { $label = 'Would delete (folders only if empty)' }
Write-Output ("{0}: {1} files, {2} folders. Skipped links: {3}. Errors: {4}." -f
    $label, $stats.Files, $stats.Folders, $stats.Links, $stats.Errors)
if ($stats.Errors -gt 0) { exit 1 }
exit 0
