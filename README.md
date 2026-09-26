# Clean Airport

Clean up common macOS and AirPort Time Capsule "shared disk" metadata on a Windows file server, starting in the script's own folder and continuing through its descendants.

**Requires Windows PowerShell 5.1 or newer.**

## Quick start

1. Place `clean_airport.bat` and `clean_airport.ps1` **together in the folder you want to clean**.
2. Open PowerShell in that folder and preview the cleanup:

   ```powershell
   .\clean_airport.bat -Preview
   ```

3. Review the results, then run the cleanup:

   ```powershell
   .\clean_airport.bat
   ```

No installation or administrator rights are required if your account already has permission to delete the matching files.

> [!WARNING]
> Cleanup permanently deletes matching files, bypassing the Recycle Bin. Double-clicking the BAT starts cleanup immediately. Use a terminal to review the output, because a double-clicked window may close when finished.

In Command Prompt, use `clean_airport.bat` instead of `.\clean_airport.bat`.

## Cleanup scope

The cleanup root is **the folder containing `clean_airport.ps1`**, regardless of the current working directory or Task Scheduler's **Start in** setting. Keep both script files together.

| Script location | Included | Excluded |
| --- | --- | --- |
| `D:\` | Files in `D:\` and all ordinary descendant folders | Other drives, such as `C:\` and `E:\` |
| `D:\subfolder` | Files in `D:\subfolder` and descendants such as `D:\subfolder\subfoldersubfolder` | The parent `D:\` and siblings such as `D:\subfolder1` and `D:\subfoldersubfolder` |

### Links and folder boundaries

- Junctions, symbolic links, volume mount points, and all other reparse points are skipped, including files.
- A cleanup root reached through a reparse point is refused.
- Each filesystem operation checks the path boundary and its ancestors.
- Selected folders are removed only after their contents have been processed and only if they are empty. There is no recursive folder-delete operation.

Run locally on the Windows file server for predictable filesystem behavior.

> [!IMPORTANT]
> Do not move folders or create or retarget links during cleanup. Path-based checks cannot guarantee protection against another process swapping a directory for a link between the safety check and the filesystem operation.

## What gets cleaned

### Files

Matching is case-insensitive and includes hidden, system, and read-only files when permissions allow deletion.

| Name or pattern | Match |
| --- | --- |
| `.DS_Store` | Exact filename |
| `.apDisk` | Exact filename |
| `desktop.ini` | Exact filename |
| `Thumbs.db` | Exact filename |
| `Thumbs.db.encryptable` | Exact filename |
| `ehthumbs.db` | Exact filename |
| `ehthumbs_vista.db` | Exact filename |
| `._*` | Any filename beginning with dot-underscore, including AppleDouble sidecars |

### Folders

The following folder names are matched exactly, without regard to case. **Their contents are deleted**, subject to the link-skipping and error-handling rules.

- `.Spotlight-V100`
- `.fseventsd`
- `.TemporaryItems`
- `.AppleDouble`

Links inside these folders are still skipped. A folder containing a skipped link or an undeletable file may remain nonempty and be reported as an error.

### Metadata considerations

> [!CAUTION]
> AppleDouble sidecars (`._*`) and `.AppleDouble` folders can contain resource forks and extended attributes, including useful tags or legacy Mac file data. Their deletion is enabled by default. Preserve these files if you need that information.

`desktop.ini` stores Windows folder customizations. `Thumbs.db` is a Windows thumbnail cache, not Finder metadata. The origin of the `.encryptable` variant has not been established; the script targets only the specific filename `Thumbs.db.encryptable`.

## Optional cleanup

| Switch | Behavior |
| --- | --- |
| `-Preview` | Lists proposed changes without modifying files or folders |
| `-IncludeTrash` | Empties and removes folders named exactly `.Trash` or `.Trashes` |
| `-IncludeLegacyAperture` | Also deletes `Master.apmaster` and files matching `*.apversion` |

Without `-IncludeTrash`, `.Trash` and `.Trashes` folders and their entire contents are skipped. Aperture files are application metadata, not general Finder clutter.

You can use the options separately or together.

Preview with both optional cleanup categories enabled:

```powershell
.\clean_airport.bat -Preview -IncludeTrash -IncludeLegacyAperture
```

Perform that cleanup:

```powershell
.\clean_airport.bat -IncludeTrash -IncludeLegacyAperture
```

## What stays untouched

Outside the explicitly selected metadata folders, the script leaves files alone unless they match a listed filename or pattern.

- No blanket `*.encryptable`, `*.db`, `.*`, or `*Trash*` matching.
- Similarly named folders are not selected for wholesale deletion.
- Metadata control markers such as `.metadata_never_index` are not targeted.
- `__MACOSX` is traversed normally: matching sidecars are deleted, but other contents are retained.
- The script does not empty the Windows Recycle Bin.

## Errors, logging, and scheduled runs

Locked or inaccessible files are reported, and cleanup continues with other items. The script does not change ownership or access permissions, stop services, or force files to unlock.

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Completed without errors; intentional link skips are not errors |
| `1` | Cleanup was incomplete, or the cleanup root was unsafe |

### Save a preview log

```powershell
.\clean_airport.bat -Preview > cleanup-preview.txt 2>&1
```

### Task Scheduler

Call the BAT by its full path. Cleanup remains anchored to the companion PS1 file's folder, regardless of Task Scheduler's **Start in** setting.

Clients can recreate metadata after cleanup.

## Reduce `.DS_Store` creation on Macs

Apple documents the following command for each Mac. Run it in Terminal, then log out and back in:

```sh
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE
```

This addresses `.DS_Store` on network shares, not every metadata format.

See [Apple's SMB browsing guidance](https://support.apple.com/en-ie/102064).
