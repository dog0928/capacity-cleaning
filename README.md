# capacity-cleaning
<img width="1289" height="586" alt="スクリーンショット 0008-05-13 午後9 01 07" src="https://github.com/user-attachments/assets/246f4ad8-0d66-4177-a348-f179898361ab" />


capacity-cleaning is a native macOS SwiftUI app for disk usage inspection and safe cleanup review.

## Current behavior

- Shows a GUI dashboard with category totals and a pie chart.
- Groups storage into user data, Library, caches, developer data, system-related data, and other large folders.
- Marks candidates as:
  - `セーフ候補`: commonly regenerated data such as Xcode DerivedData or npm cache.
  - `確認推奨`: large folders that need manual review.
  - `表示のみ`: browser caches and system-adjacent folders.
- Opens selected folders in Finder for manual inspection.
- Shows a detail panel when a candidate is clicked.
- Lists the largest folders/files inside the selected candidate.
- For Downloads, surfaces installer-style files such as `.dmg`, `.pkg`, `.mpkg`, and `.iso`.
- Shows Trash buttons for eligible `セーフ候補` and `確認推奨` detail entries.
- Supports checkbox selection and batch Trash moves from the detail panel.
- Moves eligible candidates to Trash only after a GUI confirmation.
- Supports Japanese and English UI language switching from Settings.
- Checks GitHub Releases for updates and downloads the matching DMG for the current Mac architecture.

## Safety policy

The app does not perform automatic cleanup. File operations only happen after the user clicks a Trash button and confirms the dialog.

Cleanup uses macOS Trash through `FileManager.trashItem`; it does not permanently delete files directly.

Browser cache areas are intentionally shown as `表示のみ`; the UI does not guide users to remove them.

System-related and `表示のみ` entries are not offered as GUI trash candidates.

## Settings and Updates

Open Settings from the gear button in the toolbar or the macOS Settings menu.

Settings include:

- Language: System, Japanese, or English.
- Check for updates on launch.
- Manual update check.
- Download update DMG.
- Open the downloaded installer DMG.

Updates are resolved from the latest GitHub Release in `dog0928/dir-clear`. The app downloads the matching `capacity-cleaning-arm64.dmg` or `capacity-cleaning-x64.dmg` file to Downloads. To apply the update, open the downloaded DMG and drag `capacity-cleaning.app` to Applications.

The app does not silently overwrite the running application. This avoids replacing an app while it is active and keeps the final install step visible to the user.

## Build

```sh
/usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin /usr/bin/swift build
```

The debug executable is created at:

```text
.build/arm64-apple-macosx/debug/capacity-cleaning
```

## DMG

Create a downloadable macOS DMG locally:

```sh
scripts/package_dmg.sh
```

The DMG is created at:

```text
dist/capacity-cleaning.dmg
```

GitHub Actions also builds DMGs on macOS. Push a tag such as `v0.1.0` to attach downloadable DMGs to a GitHub Release; normal pushes and pull requests upload them as workflow artifacts.

The workflow builds separate DMGs for Apple Silicon and Intel Macs:

- `capacity-cleaning-arm64.dmg`
- `capacity-cleaning-x64.dmg`

The DMG contains `capacity-cleaning.app`, an `Applications` shortcut, and a visual "Drop capacity-cleaning.app to Applications" install image/background so users can drag the app into Applications.

Every push to `master` creates a GitHub Release named `master-<short-sha>` with the DMGs attached. Version tags such as `v0.1.0` create versioned releases.

These builds are ad-hoc signed for packaging. Public distribution without Gatekeeper warnings requires Apple Developer ID signing and notarization.
