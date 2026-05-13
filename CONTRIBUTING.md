# Contributing to capacity-cleaning

Thank you for your interest in contributing to capacity-cleaning.

capacity-cleaning is a native macOS SwiftUI app for disk usage inspection and safe cleanup review. Because this app deals with user files, safety and predictable behavior are more important than aggressive cleanup.

## Project goals

- Show disk usage in a clear macOS-native GUI.
- Help users review large folders and files before cleanup.
- Move eligible items to macOS Trash only after explicit user confirmation.
- Avoid permanent deletion, silent cleanup, background cleanup, or destructive automation.
- Keep system-related and sensitive locations conservative by default.
- Support Japanese and English UI.

## Ways to contribute

- Report bugs.
- Suggest safer cleanup candidate rules.
- Improve SwiftUI UI/UX.
- Improve Japanese or English localization.
- Improve packaging and GitHub Actions.
- Improve documentation.
- Test the app on different macOS versions and Mac architectures.

## Before opening an issue

Please check:

1. You are using the latest release.
2. The issue still happens after restarting the app.
3. The issue is not caused by a macOS permission limitation.
4. A similar issue has not already been reported.

Include:

- macOS version
- Mac architecture: Apple Silicon or Intel
- App version or commit hash
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots or logs if available

Do not include private file paths, personal files, access tokens, or other sensitive information unless they are fully redacted.

## Safety rules

Do not add behavior that:

- Permanently deletes files directly.
- Deletes files without a confirmation dialog.
- Automatically cleans files on launch.
- Runs background cleanup without user action.
- Encourages users to remove browser caches or system-adjacent folders without review.
- Marks risky folders as safe without a clear reason.
- Requires Full Disk Access unless discussed first.
- Silently replaces the running app during updates.

Allowed cleanup behavior should use macOS Trash, not direct deletion.

If your change affects cleanup candidates, candidate labels, Trash buttons, update downloads, or path scanning, explain the safety impact in the pull request.

## Development setup

### Requirements

- macOS
- Xcode command line tools
- Swift Package Manager
- Git

Check your toolchain:

```sh
swift --version
xcodebuild -version
````

Clone the repository:

```sh
git clone https://github.com/dog0928/capacity-cleaning.git
cd capacity-cleaning
```

Build:

```sh
/usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin /usr/bin/swift build
```

The debug executable is created under:

```text
.build/arm64-apple-macosx/debug/capacity-cleaning
```

The exact path may differ depending on your Mac architecture and Swift toolchain.

## Packaging DMG locally

Create a local DMG:

```sh
scripts/package_dmg.sh
```

Default output:

```text
dist/capacity-cleaning.dmg
```

The DMG should contain:

* `capacity-cleaning.app`
* An `Applications` shortcut
* A visual drag-to-Applications instruction if applicable

Expected release asset names:

```text
capacity-cleaning-arm64.dmg
capacity-cleaning-x64.dmg
```

Do not rename release DMG assets without updating the app's update-checking code and README.

## Branch workflow

Use a dedicated branch:

```sh
git checkout -b fix/short-description
```

Recommended prefixes:

* `fix/`
* `feature/`
* `docs/`
* `ci/`
* `refactor/`

## Pull request checklist

Before opening a pull request:

* [ ] The project builds successfully.
* [ ] The app launches.
* [ ] DMG packaging works if packaging is affected.
* [ ] File operations still require explicit user confirmation.
* [ ] Risky paths are not promoted to safe cleanup candidates without explanation.
* [ ] Japanese and English UI text are both updated when user-facing text changes.
* [ ] README or documentation is updated when behavior changes.

## Pull request template

```md
## Summary

Describe what changed.

## Reason

Explain why this change is needed.

## Safety impact

Explain whether this affects scanning, cleanup candidates, Trash behavior, update downloads, or user files.

## Test checklist

- [ ] `swift build` passes
- [ ] App launches
- [ ] DMG packaging works if relevant
- [ ] Japanese UI checked if relevant
- [ ] English UI checked if relevant
```

## Coding style

Prefer:

* Clear Swift names.
* Small focused types.
* Explicit safety checks before file operations.
* Conservative cleanup classification.
* Readable SwiftUI views.

Avoid:

* Large unrelated rewrites.
* Hidden background work.
* Force-unwrapping when avoidable.
* Silent failure for file operations.
* Adding dependencies without a clear reason.
* Mixing formatting-only changes with behavior changes.

## Localization

When adding or changing user-facing text:

* Update both Japanese and English strings.
* Keep safety-related labels clear and conservative.
* Avoid wording that makes deletion sound risk-free.
* Prefer "review", "candidate", "move to Trash", and "manual confirmation" over aggressive cleanup wording.

## Cleanup candidate labels

Current label meanings:

* `セーフ候補`: commonly regenerated data, but still requires confirmation.
* `確認推奨`: large folders or files that need manual review.
* `表示のみ`: visible for inspection only; not offered as a cleanup action.

Do not treat `セーフ候補` as "always safe to delete."

## Security

Do not include:

* Secrets
* Access tokens
* Private certificates
* Personal file paths in examples
* User-specific local paths in committed files
* Generated build products
* DMG artifacts unless explicitly required

If you find a security issue, do not open a public issue with exploit details.

## GitHub Actions

If you change the workflow:

* Keep release assets architecture-specific.
* Keep pull requests artifact-only unless release behavior is intentional.
* Do not require secrets for normal pull request builds.
* Keep release upload permissions limited to what is needed.
* Verify that both architecture jobs still upload artifacts.

## Release behavior

Version tags such as `v0.1.0` are used for release builds.

Before changing release behavior, check:

* The app's update checker
* README update instructions
* DMG asset names
* GitHub Actions release upload behavior

The app should not silently overwrite the running application. Updates should remain a visible user-controlled install step.

## License

By contributing to this repository, you agree that your contributions will be licensed under the same license as the project.
