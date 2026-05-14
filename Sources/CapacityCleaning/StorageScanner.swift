import Foundation

struct DirectoryMeasure {
    let bytes: Int64
    let fileCount: Int
    let unreadablePaths: Int
}

actor StorageScanner {
    private let fileManager = FileManager.default
    private let byteThreshold: Int64 = 500 * 1024 * 1024

    func scanHome() async -> ScanReport {
        scan()
    }

    func detail(for item: ScanItem) async -> ItemDetail {
        scanDetail(for: item)
    }

    private func scan() -> ScanReport {
        let home = fileManager.homeDirectoryForCurrentUser
        var summaries: [StorageCategory: (bytes: Int64, count: Int)] = [:]
        var candidates: [ScanItem] = []
        var unreadablePaths = 0

        let roots = scanRoots(home: home)
        for root in roots {
            guard fileManager.fileExists(atPath: root.url.path) else { continue }
            let measure = measureDirectory(root.url, maxDepth: root.maxDepth)
            unreadablePaths += measure.unreadablePaths
            summaries[root.category, default: (0, 0)].bytes += measure.bytes
            summaries[root.category, default: (0, 0)].count += measure.fileCount

            if measure.bytes >= root.minimumBytesForDisplay {
                candidates.append(
                    ScanItem(
                        name: root.name,
                        path: root.url.path,
                        category: root.category,
                        level: root.level,
                        bytes: measure.bytes,
                        fileCount: measure.fileCount,
                        reason: root.reason
                    )
                )
            }
        }

        candidates.append(contentsOf: discoverSystemDataCleanupFolders(in: home))
        candidates.append(contentsOf: discoverLargeFolders(in: home))
        candidates.append(contentsOf: discoverLargeFiles(in: home))

        let explainedBytes = measuredVolumeBytes(home: home)
        let volumeInfo = volumeStorageInfo(explainedBytes: explainedBytes)
        let systemDataExplanations = systemDataExplanations(home: home, hiddenBytes: volumeInfo?.hiddenSystemBytes)
        if let hiddenBytes = volumeInfo?.hiddenSystemBytes, hiddenBytes > 0 {
            summaries[.systemDataEstimate, default: (0, 0)].bytes += hiddenBytes
        }

        let categorySummaries = StorageCategory.allCases.map { category in
            let value = summaries[category] ?? (0, 0)
            return CategorySummary(category: category, bytes: value.bytes, itemCount: value.count)
        }
        .filter { $0.bytes > 0 }
        .sorted { $0.bytes > $1.bytes }

        let uniqueCandidates = Dictionary(grouping: candidates, by: \.path)
            .compactMap { $0.value.max { $0.bytes < $1.bytes } }
            .sorted { $0.bytes > $1.bytes }

        return ScanReport(
            generatedAt: Date(),
            homePath: home.path,
            summaries: categorySummaries,
            items: uniqueCandidates,
            unreadablePaths: unreadablePaths,
            volumeInfo: volumeInfo,
            systemDataExplanations: systemDataExplanations
        )
    }

    private func volumeStorageInfo(explainedBytes: Int64) -> VolumeStorageInfo? {
        let root = URL(fileURLWithPath: "/")
        guard let values = try? root.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity else {
            return nil
        }

        let totalBytes = Int64(total)
        let availableBytes = Int64(available)
        let usedBytes = max(0, totalBytes - availableBytes)
        let hiddenBytes = max(0, usedBytes - explainedBytes)
        return VolumeStorageInfo(
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            usedBytes: usedBytes,
            explainedBytes: explainedBytes,
            hiddenSystemBytes: hiddenBytes
        )
    }

    private func systemDataExplanations(home: URL, hiddenBytes: Int64?) -> [SystemDataExplanation] {
        var explanations: [SystemDataExplanation] = []

        func append(
            _ id: String,
            name: String,
            path: String,
            bytes: Int64? = nil,
            isDeletableCandidate: Bool,
            reason: String
        ) {
            explanations.append(
                SystemDataExplanation(
                    id: id,
                    name: name,
                    path: path,
                    bytes: bytes,
                    isDeletableCandidate: isDeletableCandidate,
                    reason: reason
                )
            )
        }

        let logs = home.appendingPathComponent("Library/Logs")
        if fileManager.fileExists(atPath: logs.path) {
            let measure = measureDirectory(logs, maxDepth: 3)
            if measure.bytes > 0 {
                append(
                    "user-logs",
                    name: "User Logs",
                    path: logs.path,
                    bytes: measure.bytes,
                    isDeletableCandidate: true,
                    reason: "ユーザーのログです。古いログは削除しても再作成されますが、直近のトラブル調査に使う場合があります。"
                )
            }
        }

        let backups = home.appendingPathComponent("Library/Application Support/MobileSync/Backup")
        if fileManager.fileExists(atPath: backups.path) {
            let measure = measureDirectory(backups, maxDepth: 3)
            if measure.bytes > 0 {
                append(
                    "ios-backups",
                    name: "iOS Device Backups",
                    path: backups.path,
                    bytes: measure.bytes,
                    isDeletableCandidate: true,
                    reason: "iPhoneやiPadのローカルバックアップです。削除するとそのバックアップから復元できなくなるため、必要性を確認してください。"
                )
            }
        }

        let savedState = home.appendingPathComponent("Library/Saved Application State")
        if fileManager.fileExists(atPath: savedState.path) {
            let measure = measureDirectory(savedState, maxDepth: 2)
            if measure.bytes > 0 {
                append(
                    "saved-application-state",
                    name: "Saved Application State",
                    path: savedState.path,
                    bytes: measure.bytes,
                    isDeletableCandidate: true,
                    reason: "アプリのウィンドウ復元や終了時状態です。削除すると一部アプリの復元状態は消えますが、必要に応じて再作成されます。"
                )
            }
        }

        let diagnosticReports = home.appendingPathComponent("Library/Logs/DiagnosticReports")
        if fileManager.fileExists(atPath: diagnosticReports.path) {
            let measure = measureDirectory(diagnosticReports, maxDepth: 2)
            if measure.bytes > 0 {
                append(
                    "diagnostic-reports",
                    name: "Diagnostic Reports",
                    path: diagnosticReports.path,
                    bytes: measure.bytes,
                    isDeletableCandidate: true,
                    reason: "クラッシュログや診断レポートです。古いものは削除できますが、直近の不具合調査に使う場合があります。"
                )
            }
        }

        let xcodeDeviceSupport = home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")
        if fileManager.fileExists(atPath: xcodeDeviceSupport.path) {
            let measure = measureDirectory(xcodeDeviceSupport, maxDepth: 3)
            if measure.bytes > 0 {
                append(
                    "xcode-device-support",
                    name: "Xcode DeviceSupport",
                    path: xcodeDeviceSupport.path,
                    bytes: measure.bytes,
                    isDeletableCandidate: true,
                    reason: "接続したiPhoneやiPad用にXcodeが保存したサポートデータです。古いOS端末を使わない場合は削除候補になります。"
                )
            }
        }

        let xcodeArchives = home.appendingPathComponent("Library/Developer/Xcode/Archives")
        if fileManager.fileExists(atPath: xcodeArchives.path) {
            let measure = measureDirectory(xcodeArchives, maxDepth: 3)
            if measure.bytes > 0 {
                append(
                    "xcode-archives",
                    name: "Xcode Archives",
                    path: xcodeArchives.path,
                    bytes: measure.bytes,
                    isDeletableCandidate: true,
                    reason: "Xcodeの配布用アーカイブです。削除すると再アップロードや再署名に必要な履歴を失う可能性があります。不要なものだけ確認してください。"
                )
            }
        }

        let simulatorCaches = home.appendingPathComponent("Library/Developer/CoreSimulator/Caches")
        if fileManager.fileExists(atPath: simulatorCaches.path) {
            let measure = measureDirectory(simulatorCaches, maxDepth: 3)
            if measure.bytes > 0 {
                append(
                    "simulator-caches",
                    name: "Simulator Caches",
                    path: simulatorCaches.path,
                    bytes: measure.bytes,
                    isDeletableCandidate: true,
                    reason: "Simulatorが作るキャッシュです。削除後に必要なデータは再生成されますが、SimulatorやXcodeを終了してから操作してください。"
                )
            }
        }

        let moreDeletableSystemData = [
            ("quicklook-cache", "QuickLook Thumbnail Cache", home.appendingPathComponent("Library/Caches/com.apple.QuickLook.thumbnailcache"), "QuickLookのサムネイルキャッシュです。必要に応じて再生成されるため削除候補になります。"),
            ("messages-attachments", "Messages Attachments", home.appendingPathComponent("Library/Messages/Attachments"), "メッセージの添付ファイルです。削除すると会話内の添付を失う可能性があるため、不要なものだけ確認してください。"),
            ("mail-downloads", "Mail Downloads", home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"), "メールから開いた添付ファイルの保存領域です。必要な添付を別保存している場合は削除候補になります。"),
            ("ios-software-updates", "iOS Software Updates", home.appendingPathComponent("Library/iTunes/iPhone Software Updates"), "iPhoneやiPadのアップデートファイルです。必要になれば再取得できるため削除候補になります。"),
            ("xcode-ios-device-logs", "Xcode iOS Device Logs", home.appendingPathComponent("Library/Developer/Xcode/iOS Device Logs"), "Xcodeが保存した実機デバイスログです。古いログは削除候補になります。"),
            ("xcode-previews-devices", "Xcode Previews Simulator Devices", home.appendingPathComponent("Library/Developer/Xcode/UserData/Previews/Simulator Devices"), "SwiftUI Previews用のSimulatorデータです。Xcodeを終了してから不要なものを確認してください。"),
            ("swiftpm-cache", "SwiftPM Cache", home.appendingPathComponent("Library/Caches/org.swift.swiftpm"), "Swift Package Managerのキャッシュです。必要時に再取得されます。"),
            ("homebrew-cache", "Homebrew Cache", home.appendingPathComponent("Library/Caches/Homebrew"), "Homebrewのダウンロードキャッシュです。必要時に再取得できます。"),
            ("pip-cache", "pip Cache", home.appendingPathComponent("Library/Caches/pip"), "Python pipのキャッシュです。必要時に再取得されます。"),
            ("gradle-cache", "Gradle Cache", home.appendingPathComponent(".gradle/caches"), "Gradleの依存関係キャッシュです。ビルド時に再取得されます。"),
            ("maven-cache", "Maven Repository Cache", home.appendingPathComponent(".m2/repository"), "Mavenのローカル依存関係リポジトリです。再取得できますが、次回ビルド時間が増える可能性があります。"),
            ("cargo-registry-cache", "Cargo Registry Cache", home.appendingPathComponent(".cargo/registry"), "Rust Cargoのレジストリキャッシュです。必要時に再取得されます。")
        ]

        for item in moreDeletableSystemData where fileManager.fileExists(atPath: item.2.path) {
            let measure = measureDirectory(item.2, maxDepth: 3)
            guard measure.bytes > 0 else { continue }
            append(
                item.0,
                name: item.1,
                path: item.2.path,
                bytes: measure.bytes,
                isDeletableCandidate: true,
                reason: item.3
            )
        }

        if let hiddenBytes, hiddenBytes > 0 {
            append(
                "hidden-estimate",
                name: "Hidden System Data Estimate",
                path: "/",
                bytes: hiddenBytes,
                isDeletableCandidate: false,
                reason: "システムデータの推定差分です。読み取り不可領域やOS管理データが混ざるため、直接削除できる1つのフォルダーとして扱えません。"
            )
        }

        append(
            "apfs-snapshots",
            name: "APFS Snapshots / Local Time Machine",
            path: "APFS snapshots",
            isDeletableCandidate: false,
            reason: "APFSスナップショットやローカルTime Machineは復元とバックアップ整合性に関わります。通常のフォルダーではないため、このアプリでは削除対象にしません。"
        )

        let vm = URL(fileURLWithPath: "/private/var/vm")
        let vmBytes = fileManager.fileExists(atPath: vm.path) ? measureDirectory(vm, maxDepth: 1).bytes : nil
        append(
            "virtual-memory",
            name: "Virtual Memory / Sleep Files",
            path: vm.path,
            bytes: vmBytes,
            isDeletableCandidate: false,
            reason: "仮想メモリとスリープ関連ファイルです。起動中のmacOSが使うため、手動削除すると不安定化やデータ損失につながる可能性があります。"
        )

        append(
            "system-volume",
            name: "System Volume",
            path: "/System",
            isDeletableCandidate: false,
            reason: "macOS本体とシステム保護領域です。削除すると起動不能やアップデート失敗につながるため対象外です。"
        )

        append(
            "spotlight",
            name: "Spotlight Index",
            path: "/.Spotlight-V100",
            isDeletableCandidate: false,
            reason: "Spotlightの検索インデックスです。削除すると検索やメタデータ処理が壊れたり、再構築で一時的に負荷が上がるため対象外です。"
        )

        append(
            "shared-library",
            name: "Shared System Library",
            path: "/Library",
            isDeletableCandidate: false,
            reason: "共有フレームワーク、拡張、ドライバ、アプリ共通データが含まれます。依存関係が分かりにくいため削除対象外です。"
        )

        return explanations
    }

    private func measuredVolumeBytes(home: URL) -> Int64 {
        let roots = [
            MeasuredRoot(url: home, maxDepth: 7),
            MeasuredRoot(url: URL(fileURLWithPath: "/Applications"), maxDepth: 5),
            MeasuredRoot(url: URL(fileURLWithPath: "/Library"), maxDepth: 5),
            MeasuredRoot(url: URL(fileURLWithPath: "/private/var"), maxDepth: 5),
            MeasuredRoot(url: URL(fileURLWithPath: "/usr/local"), maxDepth: 5),
            MeasuredRoot(url: URL(fileURLWithPath: "/opt"), maxDepth: 5),
            MeasuredRoot(url: URL(fileURLWithPath: "/Users/Shared"), maxDepth: 5)
        ]

        var measured: Int64 = 0
        var seen = Set<String>()
        for root in roots {
            let path = root.url.standardizedFileURL.path
            guard fileManager.fileExists(atPath: path), !seen.contains(path) else { continue }
            seen.insert(path)
            measured += measureDirectory(root.url, maxDepth: root.maxDepth).bytes
        }
        return measured
    }

    private func scanRoots(home: URL) -> [ScanRoot] {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let varFolderCache = tempDirectory.deletingLastPathComponent().appendingPathComponent("C", isDirectory: true)

        return [
            ScanRoot(
                name: "Downloads",
                url: home.appendingPathComponent("Downloads"),
                category: .userFiles,
                level: .review,
                reason: "ダウンロード済みのインストーラ、動画、アーカイブが溜まりやすい場所です。",
                minimumBytesForDisplay: 0,
                maxDepth: 4
            ),
            ScanRoot(
                name: "Documents",
                url: home.appendingPathComponent("Documents"),
                category: .userFiles,
                level: .review,
                reason: "大きい書類や作業フォルダを見つけるための表示です。",
                minimumBytesForDisplay: byteThreshold,
                maxDepth: 4
            ),
            ScanRoot(
                name: "Movies",
                url: home.appendingPathComponent("Movies"),
                category: .userFiles,
                level: .review,
                reason: "動画素材や画面収録が容量を使っている可能性があります。",
                minimumBytesForDisplay: byteThreshold,
                maxDepth: 4
            ),
            ScanRoot(
                name: "Pictures",
                url: home.appendingPathComponent("Pictures"),
                category: .userFiles,
                level: .review,
                reason: "写真ライブラリや画像素材の容量確認用です。",
                minimumBytesForDisplay: byteThreshold,
                maxDepth: 3
            ),
            ScanRoot(
                name: "User Library",
                url: home.appendingPathComponent("Library"),
                category: .userLibrary,
                level: .review,
                reason: "アプリの設定やサポートデータが含まれるため、削除ではなく確認対象として扱います。",
                minimumBytesForDisplay: 2 * byteThreshold,
                maxDepth: 2
            ),
            ScanRoot(
                name: "Application Support",
                url: home.appendingPathComponent("Library/Application Support"),
                category: .userLibrary,
                level: .review,
                reason: "アプリごとの保存データです。用途が分かるものだけ確認してください。",
                minimumBytesForDisplay: byteThreshold,
                maxDepth: 2
            ),
            ScanRoot(
                name: "General Caches",
                url: home.appendingPathComponent("Library/Caches"),
                category: .caches,
                level: .safe,
                reason: "多くは再生成される一時データです。ブラウザ系は表示のみとして別扱いします。",
                minimumBytesForDisplay: 200 * 1024 * 1024,
                maxDepth: 2
            ),
            ScanRoot(
                name: "Safari Cache",
                url: home.appendingPathComponent("Library/Caches/com.apple.Safari"),
                category: .caches,
                level: .observe,
                reason: "ブラウザキャッシュです。削除誘導はせず、容量と場所だけを表示します。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Chrome Cache",
                url: home.appendingPathComponent("Library/Caches/Google/Chrome"),
                category: .caches,
                level: .observe,
                reason: "ブラウザキャッシュです。削除誘導はせず、容量と場所だけを表示します。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Firefox Cache",
                url: home.appendingPathComponent("Library/Caches/Firefox"),
                category: .caches,
                level: .observe,
                reason: "ブラウザキャッシュです。削除誘導はせず、容量と場所だけを表示します。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Xcode DerivedData",
                url: home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                category: .developer,
                level: .safe,
                reason: "Xcodeが再生成するビルド生成物です。作業中プロジェクトがないか確認してください。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "CoreSimulator",
                url: home.appendingPathComponent("Library/Developer/CoreSimulator"),
                category: .developer,
                level: .review,
                reason: "Simulatorの端末データやランタイムです。必要な端末がないか確認してください。",
                minimumBytesForDisplay: byteThreshold,
                maxDepth: 3
            ),
            ScanRoot(
                name: "npm Cache",
                url: home.appendingPathComponent(".npm"),
                category: .developer,
                level: .safe,
                reason: "npmのキャッシュ領域です。必要時に再取得されます。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "User Logs",
                url: home.appendingPathComponent("Library/Logs"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "ユーザーのログです。古いログは削除しても再作成されますが、直近のトラブル調査に使う場合があります。",
                minimumBytesForDisplay: 10 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "iOS Device Backups",
                url: home.appendingPathComponent("Library/Application Support/MobileSync/Backup"),
                category: .systemDataEstimate,
                level: .review,
                reason: "iPhoneやiPadのローカルバックアップです。削除するとそのバックアップから復元できなくなるため、必要性を確認してください。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Saved Application State",
                url: home.appendingPathComponent("Library/Saved Application State"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "アプリのウィンドウ復元や終了時状態です。削除すると一部アプリの復元状態は消えますが、必要に応じて再作成されます。",
                minimumBytesForDisplay: 10 * 1024 * 1024,
                maxDepth: 2
            ),
            ScanRoot(
                name: "Diagnostic Reports",
                url: home.appendingPathComponent("Library/Logs/DiagnosticReports"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "クラッシュログや診断レポートです。古いものは削除できますが、直近の不具合調査に使う場合があります。",
                minimumBytesForDisplay: 10 * 1024 * 1024,
                maxDepth: 2
            ),
            ScanRoot(
                name: "Xcode DeviceSupport",
                url: home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
                category: .systemDataEstimate,
                level: .review,
                reason: "接続したiPhoneやiPad用にXcodeが保存したサポートデータです。古いOS端末を使わない場合は削除候補になります。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Xcode Archives",
                url: home.appendingPathComponent("Library/Developer/Xcode/Archives"),
                category: .systemDataEstimate,
                level: .review,
                reason: "Xcodeの配布用アーカイブです。削除すると再アップロードや再署名に必要な履歴を失う可能性があります。不要なものだけ確認してください。",
                minimumBytesForDisplay: byteThreshold,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Simulator Caches",
                url: home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "Simulatorが作るキャッシュです。削除後に必要なデータは再生成されますが、SimulatorやXcodeを終了してから操作してください。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "User Temporary Items",
                url: tempDirectory,
                category: .systemDataEstimate,
                level: .safe,
                reason: "macOSがユーザーごとに割り当てる一時フォルダーです。起動中アプリが使っている可能性があるため、古い項目だけ確認してください。",
                minimumBytesForDisplay: 10 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "User var/folders Cache",
                url: varFolderCache,
                category: .systemDataEstimate,
                level: .safe,
                reason: "macOSのユーザー別キャッシュ領域です。多くは再生成されますが、実行中アプリのデータがないか確認してください。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "HTTP Storages",
                url: home.appendingPathComponent("Library/HTTPStorages"),
                category: .systemDataEstimate,
                level: .review,
                reason: "アプリやWebViewが保存するHTTPデータです。ログイン状態やオフラインデータに関係する場合があるため確認対象です。",
                minimumBytesForDisplay: 25 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "QuickLook Thumbnail Cache",
                url: home.appendingPathComponent("Library/Caches/com.apple.QuickLook.thumbnailcache"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "QuickLookのサムネイルキャッシュです。必要に応じて再生成されるため削除候補になります。",
                minimumBytesForDisplay: 10 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Messages Attachments",
                url: home.appendingPathComponent("Library/Messages/Attachments"),
                category: .systemDataEstimate,
                level: .review,
                reason: "メッセージの添付ファイルです。削除すると会話内の添付を失う可能性があるため、不要なものだけ確認してください。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 4
            ),
            ScanRoot(
                name: "Mail Downloads",
                url: home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
                category: .systemDataEstimate,
                level: .review,
                reason: "メールから開いた添付ファイルの保存領域です。必要な添付を別保存している場合は削除候補になります。",
                minimumBytesForDisplay: 25 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "iOS Software Updates",
                url: home.appendingPathComponent("Library/iTunes/iPhone Software Updates"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "iPhoneやiPadのアップデートファイルです。必要になれば再取得できるため削除候補になります。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 2
            ),
            ScanRoot(
                name: "Xcode iOS Device Logs",
                url: home.appendingPathComponent("Library/Developer/Xcode/iOS Device Logs"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "Xcodeが保存した実機デバイスログです。古いログは削除候補になります。",
                minimumBytesForDisplay: 10 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Xcode Previews Simulator Devices",
                url: home.appendingPathComponent("Library/Developer/Xcode/UserData/Previews/Simulator Devices"),
                category: .systemDataEstimate,
                level: .review,
                reason: "SwiftUI Previews用のSimulatorデータです。Xcodeを終了してから不要なものを確認してください。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "SwiftPM Cache",
                url: home.appendingPathComponent("Library/Caches/org.swift.swiftpm"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "Swift Package Managerのキャッシュです。必要時に再取得されます。",
                minimumBytesForDisplay: 25 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Homebrew Cache",
                url: home.appendingPathComponent("Library/Caches/Homebrew"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "Homebrewのダウンロードキャッシュです。必要時に再取得できます。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "pip Cache",
                url: home.appendingPathComponent("Library/Caches/pip"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "Python pipのキャッシュです。必要時に再取得されます。",
                minimumBytesForDisplay: 25 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Gradle Cache",
                url: home.appendingPathComponent(".gradle/caches"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "Gradleの依存関係キャッシュです。ビルド時に再取得されます。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 4
            ),
            ScanRoot(
                name: "Maven Repository Cache",
                url: home.appendingPathComponent(".m2/repository"),
                category: .systemDataEstimate,
                level: .review,
                reason: "Mavenのローカル依存関係リポジトリです。再取得できますが、次回ビルド時間が増える可能性があります。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 4
            ),
            ScanRoot(
                name: "Cargo Registry Cache",
                url: home.appendingPathComponent(".cargo/registry"),
                category: .systemDataEstimate,
                level: .safe,
                reason: "Rust Cargoのレジストリキャッシュです。必要時に再取得されます。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 4
            ),
            ScanRoot(
                name: "System Cache Overview",
                url: URL(fileURLWithPath: "/Library/Caches"),
                category: .systemDataEstimate,
                level: .observe,
                reason: "全ユーザー共通のキャッシュです。権限や依存関係があるため、容量把握のみ行います。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "System Logs Overview",
                url: URL(fileURLWithPath: "/Library/Logs"),
                category: .systemDataEstimate,
                level: .observe,
                reason: "全ユーザー共通のログです。原因調査や管理者権限に関わるため、容量把握のみ行います。",
                minimumBytesForDisplay: 50 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "macOS Update Data",
                url: URL(fileURLWithPath: "/Library/Updates"),
                category: .systemDataEstimate,
                level: .observe,
                reason: "macOSアップデート用データです。削除するとアップデートや復旧に影響する可能性があるため表示のみです。",
                minimumBytesForDisplay: 100 * 1024 * 1024,
                maxDepth: 3
            ),
            ScanRoot(
                name: "Applications",
                url: URL(fileURLWithPath: "/Applications"),
                category: .other,
                level: .review,
                reason: "インストール済みアプリ本体です。不要なアプリや巨大なアプリを確認するための表示です。",
                minimumBytesForDisplay: byteThreshold,
                maxDepth: 3
            ),
            ScanRoot(
                name: "System Library",
                url: URL(fileURLWithPath: "/Library"),
                category: .system,
                level: .observe,
                reason: "共有ライブラリやシステム寄りのデータです。容量把握のみを目的にします。",
                minimumBytesForDisplay: 2 * byteThreshold,
                maxDepth: 2
            )
        ]
    }

    private func discoverSystemDataCleanupFolders(in home: URL) -> [ScanItem] {
        var items: [ScanItem] = []
        let containerRoots = [
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/Group Containers")
        ]

        for root in containerRoots {
            guard let containers = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for container in containers where isDirectory(container) && !isSymbolicLink(container) {
                let cacheCandidates = [
                    container.appendingPathComponent("Data/Library/Caches"),
                    container.appendingPathComponent("Library/Caches"),
                    container.appendingPathComponent("Caches")
                ]

                for cache in cacheCandidates where fileManager.fileExists(atPath: cache.path) {
                    let measure = measureDirectory(cache, maxDepth: 3)
                    guard measure.bytes >= 100 * 1024 * 1024 else { continue }
                    items.append(
                        ScanItem(
                            name: "Container Cache: \(container.lastPathComponent)",
                            path: cache.path,
                            category: .systemDataEstimate,
                            level: .safe,
                            bytes: measure.bytes,
                            fileCount: measure.fileCount,
                            reason: "アプリコンテナ内のキャッシュです。アプリ終了後なら再生成されやすい領域ですが、対象アプリ名を確認してください。"
                        )
                    )
                }
            }
        }

        return items
    }

    private func discoverLargeFolders(in home: URL) -> [ScanItem] {
        let searchRoots = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Developer"),
            URL(fileURLWithPath: "/Users/Shared"),
            URL(fileURLWithPath: "/Applications")
        ]

        var items: [ScanItem] = []
        var remaining = 180

        for root in searchRoots where remaining > 0 {
            guard let children = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children where remaining > 0 {
                guard isDirectory(child), !isSymbolicLink(child) else { continue }
                let measure = measureDirectory(child, maxDepth: 5)
                remaining -= 1
                guard measure.bytes >= byteThreshold else { continue }
                items.append(
                    ScanItem(
                        name: child.lastPathComponent,
                        path: child.path,
                        category: category(for: child, home: home),
                        level: levelForDiscoveredItem(child, home: home),
                        bytes: measure.bytes,
                        fileCount: measure.fileCount,
                        reason: "大きいフォルダです。中身を確認して、不要なものだけ手動で整理してください。"
                    )
                )
            }
        }

        return items
    }

    private func discoverLargeFiles(in home: URL) -> [ScanItem] {
        let roots = [
            FileSearchRoot(url: home.appendingPathComponent("Downloads"), maxDepth: 5),
            FileSearchRoot(url: home.appendingPathComponent("Desktop"), maxDepth: 4),
            FileSearchRoot(url: home.appendingPathComponent("Documents"), maxDepth: 5),
            FileSearchRoot(url: home.appendingPathComponent("Movies"), maxDepth: 5),
            FileSearchRoot(url: home.appendingPathComponent("Pictures"), maxDepth: 4),
            FileSearchRoot(url: home.appendingPathComponent("Library/Application Support"), maxDepth: 4),
            FileSearchRoot(url: home.appendingPathComponent("Library/Developer"), maxDepth: 5),
            FileSearchRoot(url: URL(fileURLWithPath: "/Users/Shared"), maxDepth: 5)
        ]

        var files: [ScanItem] = []
        var inspected = 0
        let maximumInspectedFiles = 60_000
        let minimumLargeFileBytes: Int64 = 300 * 1024 * 1024

        for root in roots where inspected < maximumInspectedFiles {
            guard fileManager.fileExists(atPath: root.url.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: root.url,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            let rootDepth = root.url.standardizedFileURL.pathComponents.count
            for case let file as URL in enumerator {
                if inspected >= maximumInspectedFiles { break }
                let depth = file.standardizedFileURL.pathComponents.count - rootDepth
                if depth > root.maxDepth {
                    if isDirectory(file) { enumerator.skipDescendants() }
                    continue
                }
                guard !isSymbolicLink(file), !isDirectory(file) else { continue }
                inspected += 1
                let size = allocatedSize(file)
                guard size >= minimumLargeFileBytes || isInstallerCandidate(file) && size >= 100 * 1024 * 1024 else { continue }
                files.append(
                    ScanItem(
                        name: "Large File: \(file.lastPathComponent)",
                        path: file.path,
                        category: category(for: file, home: home),
                        level: isInstallerCandidate(file) ? .safe : .review,
                        bytes: size,
                        fileCount: 1,
                        reason: isInstallerCandidate(file)
                            ? "Downloads内のインストーラ系ファイルです。インストール済みなら不要になっている可能性があります。"
                            : "サイズの大きいファイルです。用途を確認してください。"
                    )
                )
            }
        }

        return files.sorted { $0.bytes > $1.bytes }.prefix(120).map { $0 }
    }

    private func scanDetail(for item: ScanItem) -> ItemDetail {
        let url = URL(fileURLWithPath: item.path)
        guard isDirectory(url) else {
            let entry = DetailEntry(
                name: url.lastPathComponent,
                path: url.path,
                kind: .file,
                bytes: allocatedSize(url),
                fileCount: 1,
                level: item.level,
                reason: item.reason,
                modifiedAt: modifiedDate(url)
            )
            return ItemDetail(item: item, heavyEntries: [entry], cleanupCandidates: [], unreadablePaths: 0)
        }

        var unreadablePaths = 0
        var entries: [DetailEntry] = []
        guard let children = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ItemDetail(item: item, heavyEntries: [], cleanupCandidates: [], unreadablePaths: 1)
        }

        for child in children where !isSymbolicLink(child) {
            if isDirectory(child) {
                let measure = measureDirectory(child, maxDepth: 3)
                unreadablePaths += measure.unreadablePaths
                entries.append(
                    DetailEntry(
                        name: child.lastPathComponent,
                        path: child.path,
                        kind: .folder,
                        bytes: measure.bytes,
                        fileCount: measure.fileCount,
                        level: levelForDetail(parent: item, child: child),
                        reason: reasonForDetail(parent: item, child: child),
                        modifiedAt: modifiedDate(child)
                    )
                )
            } else {
                let size = allocatedSize(child)
                entries.append(
                    DetailEntry(
                        name: child.lastPathComponent,
                        path: child.path,
                        kind: .file,
                        bytes: size,
                        fileCount: 1,
                        level: levelForDetail(parent: item, child: child),
                        reason: reasonForDetail(parent: item, child: child),
                        modifiedAt: modifiedDate(child)
                    )
                )
            }
        }

        let heavyEntries = entries
            .filter { $0.bytes > 0 }
            .sorted { $0.bytes > $1.bytes }
            .prefix(18)

        let cleanupCandidates = entries
            .filter { canOfferTrashCandidate(parent: item, entry: $0) }
            .sorted { candidateSortKey($0) > candidateSortKey($1) }
            .prefix(16)

        return ItemDetail(
            item: item,
            heavyEntries: Array(heavyEntries),
            cleanupCandidates: Array(cleanupCandidates),
            unreadablePaths: unreadablePaths
        )
    }

    private func measureDirectory(_ url: URL, maxDepth: Int) -> DirectoryMeasure {
        var total: Int64 = 0
        var files = 0
        var unreadable = 0
        var stack: [(url: URL, depth: Int)] = [(url, 0)]

        while let current = stack.popLast() {
            guard current.depth <= maxDepth else { continue }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: current.url,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isSymbolicLinkKey],
                options: [.skipsPackageDescendants]
            ) else {
                unreadable += 1
                continue
            }

            for child in contents {
                if isSymbolicLink(child) {
                    continue
                }

                if isDirectory(child) {
                    stack.append((child, current.depth + 1))
                    continue
                }

                files += 1
                total += allocatedSize(child)
            }
        }

        return DirectoryMeasure(bytes: total, fileCount: files, unreadablePaths: unreadable)
    }

    private func allocatedSize(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    private func modifiedDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private func category(for url: URL, home: URL) -> StorageCategory {
        let path = url.path
        if path.hasPrefix("/Applications") {
            return .other
        }
        if path.contains("/Library/Developer") {
            return .developer
        }
        if path.contains("/Library/Caches") {
            return .caches
        }
        if path.contains("/Library/Logs")
            || path.contains("/Library/Saved Application State")
            || path.contains("/Library/HTTPStorages")
            || path.contains("/Library/Application Support/MobileSync")
            || path.contains("/Library/Caches/com.apple.QuickLook.thumbnailcache")
            || path.contains("/Library/Messages/Attachments")
            || path.contains("/Library/Mail Downloads")
            || path.contains("/Library/iTunes/iPhone Software Updates")
            || path.contains("/Library/Caches/Homebrew")
            || path.contains("/Library/Caches/pip")
            || path.contains("/.gradle/caches")
            || path.contains("/.m2/repository")
            || path.contains("/.cargo/registry")
            || path.contains("/var/folders") {
            return .systemDataEstimate
        }
        if path.contains("/Library/Application Support") || path.contains("/Library/") {
            return .userLibrary
        }
        return .userFiles
    }

    private func levelForDiscoveredItem(_ url: URL, home: URL) -> RecommendationLevel {
        let path = url.path
        if path.hasPrefix("/Applications") {
            return .review
        }
        if path.contains("/Library/Caches") || path.contains("/Library/Logs") || path.contains("/var/folders") {
            return .safe
        }
        return .review
    }

    private func levelForDetail(parent: ScanItem, child: URL) -> RecommendationLevel {
        if parent.level == .observe || parent.category == .system {
            return .observe
        }
        if isInstallerCandidate(child) || parent.level == .safe {
            return .safe
        }
        return .review
    }

    private func reasonForDetail(parent: ScanItem, child: URL) -> String {
        if isInstallerCandidate(child) {
            return "Downloads内のインストーラ系ファイルです。インストール済みなら不要になっている可能性があります。"
        }
        if parent.level == .safe {
            return "再生成されやすい領域の中身です。削除前にアプリが起動中でないことを確認してください。"
        }
        if isDirectory(child) {
            return "このフォルダーが親項目の容量を多く使っています。中身を確認してください。"
        }
        return "サイズの大きいファイルです。用途を確認してください。"
    }

    private func canOfferTrashCandidate(parent: ScanItem, entry: DetailEntry) -> Bool {
        guard parent.level != .observe, parent.category != .system else { return false }
        if parent.path.hasSuffix("/Downloads") && isInstallerCandidate(URL(fileURLWithPath: entry.path)) {
            return true
        }
        return entry.level != .observe && entry.bytes >= 10 * 1024 * 1024
    }

    private func isInstallerCandidate(_ url: URL) -> Bool {
        let extensions = ["dmg", "pkg", "mpkg", "iso"]
        return extensions.contains(url.pathExtension.lowercased())
    }

    private func candidateSortKey(_ entry: DetailEntry) -> Int64 {
        var score = entry.bytes
        if isOlderThanThirtyDays(entry.modifiedAt) {
            score += 2 * 1024 * 1024 * 1024
        }
        return score
    }

    private func isOlderThanThirtyDays(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Date().timeIntervalSince(date) > 30 * 24 * 60 * 60
    }
}

private struct ScanRoot {
    let name: String
    let url: URL
    let category: StorageCategory
    let level: RecommendationLevel
    let reason: String
    let minimumBytesForDisplay: Int64
    let maxDepth: Int
}

private struct MeasuredRoot {
    let url: URL
    let maxDepth: Int
}

private struct FileSearchRoot {
    let url: URL
    let maxDepth: Int
}
