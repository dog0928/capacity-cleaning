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

        candidates.append(contentsOf: discoverLargeFolders(in: home))

        let explainedBytes = summaries.reduce(Int64(0)) { $0 + $1.value.bytes }
        let volumeInfo = volumeStorageInfo(explainedBytes: explainedBytes)
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
            volumeInfo: volumeInfo
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

    private func scanRoots(home: URL) -> [ScanRoot] {
        [
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

    private func discoverLargeFolders(in home: URL) -> [ScanItem] {
        let searchRoots = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Library/Application Support")
        ]

        var items: [ScanItem] = []
        var remaining = 80

        for root in searchRoots where remaining > 0 {
            guard let children = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children where remaining > 0 {
                guard isDirectory(child), !isSymbolicLink(child) else { continue }
                let measure = measureDirectory(child, maxDepth: 3)
                remaining -= 1
                guard measure.bytes >= byteThreshold else { continue }
                items.append(
                    ScanItem(
                        name: child.lastPathComponent,
                        path: child.path,
                        category: category(for: child, home: home),
                        level: .review,
                        bytes: measure.bytes,
                        fileCount: measure.fileCount,
                        reason: "大きいフォルダです。中身を確認して、不要なものだけ手動で整理してください。"
                    )
                )
            }
        }

        return items
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
        if path.contains("/Library/Application Support") || path.contains("/Library/") {
            return .userLibrary
        }
        return .userFiles
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
