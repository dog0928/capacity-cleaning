import AppKit
import CryptoKit
import Foundation

struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [ReleaseAsset]
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
        case publishedAt = "published_at"
    }
}

struct UpdateInfo {
    let version: String
    let releaseName: String
    let releaseURL: URL
    let asset: ReleaseAsset
    let tag: String
    let isNewerThanCurrent: Bool
}

@MainActor
final class UpdateManager: ObservableObject {
    @Published var latest: UpdateInfo?
    @Published var downloadedDMG: URL?
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var isApplying = false
    @Published var statusKey: LocalizedKey = .updateUnknown
    @Published var errorMessage: String?

    private let releasesEndpoint = URL(string: "https://api.github.com/repos/dog0928/capacity-cleaning/releases?per_page=30")!
    private let releaseCache = FileManager.default.temporaryDirectory.appendingPathComponent("capacity-cleaning-updates", isDirectory: true)

    var installedTag: String {
        Bundle.main.object(forInfoDictionaryKey: "CCBuildTag") as? String ?? ""
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1"
    }

    var installedBuildName: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CCBuildName") as? String, !value.isEmpty {
            return value
        }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "capacity-cleaning"
    }

    var hasUpdate: Bool {
        latest?.isNewerThanCurrent == true
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            var request = URLRequest(url: releasesEndpoint)
            request.setValue("capacity-cleaning", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let releases = try decoder.decode([GitHubRelease].self, from: data)
            guard let info = bestUpdate(from: releases) else {
                latest = nil
                statusKey = .updateFailed
                errorMessage = "No release contains a matching DMG asset: \(expectedAssetName)"
                return
            }

            latest = info
            if downloadedDMG?.lastPathComponent != cachedName(for: info) {
                downloadedDMG = nil
            }
            statusKey = info.isNewerThanCurrent ? .updateAvailable : .upToDate
        } catch {
            latest = nil
            statusKey = .updateFailed
            errorMessage = error.localizedDescription
        }
    }

    func downloadUpdate() async {
        await downloadUpdate(applyAfterDownload: false)
    }

    func downloadAndApplyUpdate() async {
        if latest == nil {
            await checkForUpdates()
        }
        await downloadUpdate(applyAfterDownload: true)
    }

    private func downloadUpdate(applyAfterDownload: Bool) async {
        guard let info = latest, info.isNewerThanCurrent, !isDownloading, !isApplying else { return }
        isDownloading = true
        errorMessage = nil
        defer { isDownloading = false }

        do {
            guard let expectedDigest = info.asset.digest?.lowercased(),
                  expectedDigest.hasPrefix("sha256:"),
                  expectedDigest.dropFirst(7).count == 64,
                  expectedDigest.dropFirst(7).allSatisfy({ $0.isHexDigit }) else {
                throw UpdateError.invalidDigest
            }
            try FileManager.default.createDirectory(at: releaseCache, withIntermediateDirectories: true)
            let target = releaseCache.appendingPathComponent(cachedName(for: info))
            if FileManager.default.fileExists(atPath: target.path) {
                if try verifyDigest(of: target, expected: expectedDigest) {
                    downloadedDMG = target
                    if applyAfterDownload { applyDownloadedUpdate() }
                    return
                }
                try FileManager.default.removeItem(at: target)
            }

            guard info.asset.browserDownloadURL.scheme == "https",
                  info.asset.browserDownloadURL.host == "github.com" else {
                throw UpdateError.invalidDownloadURL
            }
            var request = URLRequest(url: info.asset.browserDownloadURL)
            request.setValue("capacity-cleaning", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 120
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            guard try verifyDigest(of: temporaryURL, expected: expectedDigest) else {
                throw UpdateError.digestMismatch
            }
            try FileManager.default.moveItem(at: temporaryURL, to: target)
            downloadedDMG = target
            if applyAfterDownload { applyDownloadedUpdate() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cachedName(for info: UpdateInfo) -> String {
        let safeTag = info.tag.replacingOccurrences(
            of: "[^A-Za-z0-9._-]", with: "-", options: .regularExpression
        )
        return "capacity-cleaning-\(safeTag)-\(architectureName).dmg"
    }

    private func verifyDigest(of file: URL, expected: String) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return "sha256:\(actual)" == expected
    }

    private enum UpdateError: LocalizedError {
        case invalidDigest, digestMismatch, invalidDownloadURL
        var errorDescription: String? {
            switch self {
            case .invalidDigest: return "The release has no valid SHA-256 digest."
            case .digestMismatch: return "Downloaded update failed SHA-256 verification."
            case .invalidDownloadURL: return "Unexpected update download host."
            }
        }
    }


    func applyDownloadedUpdate() {
        guard let downloadedDMG else {
            errorMessage = "No downloaded DMG is available."
            return
        }

        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            errorMessage = "Updates can only be applied from the packaged .app."
            return
        }

        do {
            isApplying = true
            guard let info = latest, info.isNewerThanCurrent,
                  downloadedDMG.lastPathComponent == cachedName(for: info),
                  let digest = info.asset.digest,
                  try verifyDigest(of: downloadedDMG, expected: digest.lowercased()) else {
                throw UpdateError.digestMismatch
            }
            let scriptURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("capacity-cleaning-update-\(UUID().uuidString).sh")
            try updateScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [scriptURL.path, downloadedDMG.path, bundleURL.path, String(ProcessInfo.processInfo.processIdentifier), scriptURL.path, Bundle.main.bundleIdentifier ?? "com.dog0928.capacity-cleaning", info.tag]
            try process.run()
            NSApp.terminate(nil)
        } catch {
            isApplying = false
            errorMessage = error.localizedDescription
        }
    }

    func openDownloadedInstaller() {
        guard let downloadedDMG else { return }
        NSWorkspace.shared.open(downloadedDMG)
    }

    func openReleasePage() {
        guard let latest else { return }
        NSWorkspace.shared.open(latest.releaseURL)
    }


    private var updateScript: String {
        """
        #!/bin/sh
        set -eu

        DMG_PATH="$1"
        TARGET_APP="$2"
        APP_PID="$3"
        SCRIPT_PATH="$4"
        APP_NAME="capacity-cleaning.app"
        EXPECTED_BUNDLE_ID="$5"
        EXPECTED_TAG="$6"
        MOUNT_DIR=""
        TEMP_APP=""
        BACKUP_APP=""
        INSTALLED_NEW="false"

        cleanup() {
            if [ -n "$MOUNT_DIR" ]; then
                /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || /usr/bin/hdiutil detach -force "$MOUNT_DIR" -quiet 2>/dev/null || true
            fi
            if [ -n "$BACKUP_APP" ] && [ -d "$BACKUP_APP" ]; then
                if [ "$INSTALLED_NEW" = "true" ]; then
                    /bin/rm -rf "$TARGET_APP" 2>/dev/null || true
                fi
                if [ ! -e "$TARGET_APP" ]; then
                    /bin/mv "$BACKUP_APP" "$TARGET_APP" 2>/dev/null || true
                fi
            fi
            if [ -n "$TEMP_APP" ] && [ -d "$TEMP_APP" ]; then
                /bin/rm -rf "$TEMP_APP" 2>/dev/null || true
            fi
            /bin/rm -f "$SCRIPT_PATH" 2>/dev/null || true
        }
        trap cleanup EXIT

        while /bin/kill -0 "$APP_PID" 2>/dev/null; do
            /bin/sleep 0.2
        done

        MOUNT_DIR="$(/usr/bin/mktemp -d /tmp/capacity-cleaning-mount.XXXXXX)"
        /usr/bin/hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" -quiet
        if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
            exit 1
        fi

        SOURCE_APP="$MOUNT_DIR/$APP_NAME"
        if [ ! -d "$SOURCE_APP" ]; then
            exit 1
        fi

        SOURCE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")"
        SOURCE_TAG="$(/usr/libexec/PlistBuddy -c 'Print :CCBuildTag' "$SOURCE_APP/Contents/Info.plist")"
        [ "$SOURCE_ID" = "$EXPECTED_BUNDLE_ID" ] && [ "$SOURCE_TAG" = "$EXPECTED_TAG" ] || exit 1
        /usr/bin/codesign --verify --deep --strict "$SOURCE_APP" || exit 1

        TARGET_PARENT="$(/usr/bin/dirname "$TARGET_APP")"
        TEMP_APP="$TARGET_PARENT/.capacity-cleaning-update-$$.app"
        BACKUP_APP="$TARGET_PARENT/.capacity-cleaning-backup-$$.app"

        /bin/rm -rf "$TEMP_APP" "$BACKUP_APP"
        /usr/bin/ditto "$SOURCE_APP" "$TEMP_APP"
        /bin/mv "$TARGET_APP" "$BACKUP_APP"
        /bin/mv "$TEMP_APP" "$TARGET_APP"
        INSTALLED_NEW="true"
        /usr/bin/open "$TARGET_APP"
        /bin/rm -rf "$BACKUP_APP"
        BACKUP_APP=""
        """
    }

    private func bestUpdate(from releases: [GitHubRelease]) -> UpdateInfo? {
        let candidates: [(Date, UpdateInfo)] = releases.compactMap { release in
            guard !release.draft, !release.prerelease,
                  let asset = matchingAsset(in: release),
                  let date = release.publishedAt else { return nil }
            let version = displayVersion(for: release.tagName)
            let trimmedName = release.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let releaseName = trimmedName?.isEmpty == false
                ? (trimmedName ?? release.tagName) : release.tagName
            let isNewer: Bool
            if release.tagName.hasPrefix("master-") {
                isNewer = installedTag != release.tagName && installedTag != "" && !installedTag.hasPrefix("local")
                    ? release.tagName != installedTag
                    : (installedTag == "" || installedTag.hasPrefix("local"))
            } else {
                isNewer = isVersion(version, newerThan: currentVersion)
            }
            return (date, UpdateInfo(
                version: version, releaseName: releaseName,
                releaseURL: release.htmlURL, asset: asset,
                tag: release.tagName, isNewerThanCurrent: isNewer
            ))
        }
        // The GitHub API does not promise chronological ordering for this endpoint.
        // Only the latest published release may be selected: never downgrade to an old build.
        return candidates.max { $0.0 < $1.0 }?.1
    }

    private func matchingAsset(in release: GitHubRelease) -> ReleaseAsset? {
        release.assets.first { $0.name == expectedAssetName }
            ?? release.assets.first { asset in
                asset.name.hasSuffix("-\(architectureName).dmg") && asset.name.contains("capacity-cleaning")
            }
    }

    private func displayVersion(for tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private var expectedAssetName: String {
        "capacity-cleaning-\(architectureName).dmg"
    }

    private var architectureName: String {
        #if arch(arm64)
        "arm64"
        #else
        "x64"
        #endif
    }

    private func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        guard !left.isEmpty, !right.isEmpty else { return false }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r {
                return l > r
            }
        }
        return false
    }
}
