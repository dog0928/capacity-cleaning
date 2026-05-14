import AppKit
import Foundation

struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }
}

struct UpdateInfo {
    let version: String
    let releaseURL: URL
    let asset: ReleaseAsset
    let isNewerThanCurrent: Bool
}

@MainActor
final class UpdateManager: ObservableObject {
    @Published var latest: UpdateInfo?
    @Published var downloadedDMG: URL?
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var statusKey: LocalizedKey = .updateUnknown
    @Published var errorMessage: String?

    private let releasesEndpoint = URL(string: "https://api.github.com/repos/dog0928/capacity-cleaning/releases?per_page=20")!

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1"
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

            let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
            guard let info = bestUpdate(from: releases) else {
                latest = nil
                statusKey = .updateFailed
                errorMessage = "No release contains a matching DMG asset: \(expectedAssetName)"
                return
            }

            latest = info
            statusKey = info.isNewerThanCurrent ? .updateAvailable : .upToDate
        } catch {
            latest = nil
            statusKey = .updateFailed
            errorMessage = error.localizedDescription
        }
    }

    func downloadUpdate() async {
        guard let latest, latest.isNewerThanCurrent, !isDownloading else { return }
        isDownloading = true
        errorMessage = nil
        defer { isDownloading = false }

        do {
            var request = URLRequest(url: latest.asset.browserDownloadURL)
            request.setValue("capacity-cleaning", forHTTPHeaderField: "User-Agent")
            let (temporaryURL, _) = try await URLSession.shared.download(for: request)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            let safeVersion = latest.version.replacingOccurrences(of: "/", with: "-")
            let target = downloads.appendingPathComponent("capacity-cleaning-\(safeVersion)-\(architectureName).dmg")
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: temporaryURL, to: target)
            downloadedDMG = target
        } catch {
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

    private func bestUpdate(from releases: [GitHubRelease]) -> UpdateInfo? {
        let candidates = releases.compactMap { release -> UpdateInfo? in
            guard !release.draft, !release.prerelease else { return nil }
            guard let asset = matchingAsset(in: release) else { return nil }
            let version = displayVersion(for: release.tagName)
            return UpdateInfo(
                version: version,
                releaseURL: release.htmlURL,
                asset: asset,
                isNewerThanCurrent: isReleaseTagNewer(release.tagName)
            )
        }

        return candidates.first(where: \.isNewerThanCurrent) ?? candidates.first
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

    private func isReleaseTagNewer(_ tag: String) -> Bool {
        let version = displayVersion(for: tag)
        if version.hasPrefix("master-") {
            return true
        }
        return isVersion(version, newerThan: currentVersion)
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
