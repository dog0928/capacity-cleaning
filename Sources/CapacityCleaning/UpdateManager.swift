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
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

struct UpdateInfo {
    let version: String
    let releaseURL: URL
    let asset: ReleaseAsset
}

@MainActor
final class UpdateManager: ObservableObject {
    @Published var latest: UpdateInfo?
    @Published var downloadedDMG: URL?
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var statusKey: LocalizedKey = .updateUnknown
    @Published var errorMessage: String?

    private let releaseEndpoint = URL(string: "https://api.github.com/repos/dog0928/dir-clear/releases/latest")!

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var hasUpdate: Bool {
        guard let latest else { return false }
        return isVersion(latest.version, newerThan: currentVersion)
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: releaseEndpoint)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let asset = release.assets.first(where: { $0.name == expectedAssetName }) else {
                latest = nil
                statusKey = .updateFailed
                errorMessage = "No matching DMG asset found: \(expectedAssetName)"
                return
            }

            let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            latest = UpdateInfo(version: version, releaseURL: release.htmlURL, asset: asset)
            statusKey = isVersion(version, newerThan: currentVersion) ? .updateAvailable : .upToDate
        } catch {
            latest = nil
            statusKey = .updateFailed
            errorMessage = error.localizedDescription
        }
    }

    func downloadUpdate() async {
        guard let latest, hasUpdate, !isDownloading else { return }
        isDownloading = true
        errorMessage = nil
        defer { isDownloading = false }

        do {
            let (temporaryURL, _) = try await URLSession.shared.download(from: latest.asset.browserDownloadURL)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            let target = downloads.appendingPathComponent("capacity-cleaning-\(latest.version)-\(architectureName).dmg")
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
