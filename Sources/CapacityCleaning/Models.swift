import Foundation
import SwiftUI

enum StorageCategory: String, CaseIterable, Identifiable {
    case userFiles = "ユーザーデータ"
    case userLibrary = "ライブラリ"
    case caches = "キャッシュ"
    case developer = "開発データ"
    case system = "システム関連"
    case systemDataEstimate = "見えないシステムデータ"
    case other = "その他"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .userFiles: return .teal
        case .userLibrary: return .indigo
        case .caches: return .yellow
        case .developer: return .mint
        case .system: return .red
        case .systemDataEstimate: return .purple
        case .other: return .gray
        }
    }

    var note: String {
        switch self {
        case .userFiles:
            return "Downloads、Documents、Movies などのユーザーファイルです。"
        case .userLibrary:
            return "アプリ設定やサポートデータが多い領域です。手動確認を前提にします。"
        case .caches:
            return "ブラウザやアプリのキャッシュです。削除誘導ではなく、場所と量だけを見せます。"
        case .developer:
            return "Xcode、Simulator、パッケージ管理系の作業データです。"
        case .system:
            return "macOSや共有ライブラリなどの読み取り中心の領域です。"
        case .systemDataEstimate:
            return "スナップショット、仮想メモリ、インデックス、読み取り不可領域などの推定差分です。"
        case .other:
            return "分類できなかった大きめのフォルダです。"
        }
    }

    func title(language: AppLanguage) -> String {
        guard language.resolved == .english else { return rawValue }
        switch self {
        case .userFiles: return "User Data"
        case .userLibrary: return "Library"
        case .caches: return "Caches"
        case .developer: return "Developer Data"
        case .system: return "System Related"
        case .systemDataEstimate: return "Hidden System Data"
        case .other: return "Other"
        }
    }

    func note(language: AppLanguage) -> String {
        guard language.resolved == .english else { return note }
        switch self {
        case .userFiles:
            return "User files such as Downloads, Documents, and Movies."
        case .userLibrary:
            return "App settings and support data. Review manually before cleanup."
        case .caches:
            return "Browser and app caches. Browser caches are shown for visibility only."
        case .developer:
            return "Xcode, Simulator, and package manager working data."
        case .system:
            return "macOS and shared library areas. Mostly for visibility."
        case .systemDataEstimate:
            return "Estimated difference from snapshots, virtual memory, indexes, unreadable areas, and other hidden system data."
        case .other:
            return "Large folders that could not be classified."
        }
    }
}

enum RecommendationLevel: String, CaseIterable, Identifiable {
    case safe = "セーフ候補"
    case review = "確認推奨"
    case observe = "表示のみ"

    var id: String { rawValue }

    var badgeColor: Color {
        switch self {
        case .safe: return .green
        case .review: return .orange
        case .observe: return .secondary
        }
    }

    var description: String {
        switch self {
        case .safe:
            return "再生成されやすい一時データ。削除前にFinderで中身を確認してください。"
        case .review:
            return "サイズは大きいが用途が分かれる領域。中身の確認を優先します。"
        case .observe:
            return "ブラウザキャッシュなど、削除を促さず容量把握だけにします。"
        }
    }

    func title(language: AppLanguage) -> String {
        guard language.resolved == .english else { return rawValue }
        switch self {
        case .safe: return "Safe Candidate"
        case .review: return "Needs Review"
        case .observe: return "View Only"
        }
    }

    func description(language: AppLanguage) -> String {
        guard language.resolved == .english else { return description }
        switch self {
        case .safe:
            return "Temporary data that is commonly regenerated. Review in Finder first."
        case .review:
            return "Large areas whose purpose varies. Inspect contents first."
        case .observe:
            return "Browser caches and similar data. Shown for visibility only."
        }
    }
}

enum DetailEntryKind: String, Identifiable {
    case folder = "フォルダー"
    case file = "ファイル"

    var id: String { rawValue }
}

struct CategorySummary: Identifiable, Hashable {
    let id = UUID()
    let category: StorageCategory
    let bytes: Int64
    let itemCount: Int
}

struct ScanItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let category: StorageCategory
    let level: RecommendationLevel
    let bytes: Int64
    let fileCount: Int
    let reason: String
}

struct DetailEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let kind: DetailEntryKind
    let bytes: Int64
    let fileCount: Int
    let level: RecommendationLevel
    let reason: String
    let modifiedAt: Date?

    init(
        name: String,
        path: String,
        kind: DetailEntryKind,
        bytes: Int64,
        fileCount: Int,
        level: RecommendationLevel,
        reason: String,
        modifiedAt: Date? = nil
    ) {
        self.id = path
        self.name = name
        self.path = path
        self.kind = kind
        self.bytes = bytes
        self.fileCount = fileCount
        self.level = level
        self.reason = reason
        self.modifiedAt = modifiedAt
    }
}

struct ItemDetail {
    let item: ScanItem
    let heavyEntries: [DetailEntry]
    let cleanupCandidates: [DetailEntry]
    let unreadablePaths: Int
}

struct VolumeStorageInfo {
    let totalBytes: Int64
    let availableBytes: Int64
    let usedBytes: Int64
    let explainedBytes: Int64
    let hiddenSystemBytes: Int64
}

struct ScanReport {
    let generatedAt: Date
    let homePath: String
    let summaries: [CategorySummary]
    let items: [ScanItem]
    let unreadablePaths: Int
    let volumeInfo: VolumeStorageInfo?

    var totalBytes: Int64 {
        summaries.reduce(0) { $0 + $1.bytes }
    }
}

extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
