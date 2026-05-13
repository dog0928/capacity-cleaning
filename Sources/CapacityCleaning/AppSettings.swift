import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System / システム"
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }

    var resolved: AppLanguage {
        switch self {
        case .system:
            let code = Locale.current.language.languageCode?.identifier
            return code == "ja" ? .japanese : .english
        case .japanese, .english:
            return self
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "language")
        }
    }

    @Published var checksForUpdatesOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(checksForUpdatesOnLaunch, forKey: "checksForUpdatesOnLaunch")
        }
    }

    init() {
        let languageRaw = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: languageRaw) ?? .system
        checksForUpdatesOnLaunch = UserDefaults.standard.object(forKey: "checksForUpdatesOnLaunch") as? Bool ?? true
    }

    func t(_ key: LocalizedKey) -> String {
        AppStrings.text(key, language: language.resolved)
    }

    func reason(_ value: String) -> String {
        AppStrings.reason(value, language: language.resolved)
    }
}

enum LocalizedKey: String {
    case appSubtitle
    case safetyPolicy
    case noAutomaticDelete
    case confirmBeforeDelete
    case moveToTrash
    case observeCannotDelete
    case filter
    case selectAll
    case clear
    case scan
    case scanning
    case trashConfirmTitle
    case cancel
    case trashMove
    case trashOneMessage
    case trashManyMessage
    case storageMap
    case headerDescription
    case scanningMessage
    case waiting
    case waitingBody
    case scanStart
    case total
    case unreadable
    case targets
    case detail
    case selectingTarget
    case selectTargetBody
    case clickLeftItem
    case clickLeftItemBody
    case cleanupCandidates
    case noCleanupCandidates
    case heavyContents
    case noContents
    case batchTrash
    case file
    case folder
    case settings
    case language
    case updates
    case currentVersion
    case autoCheckUpdates
    case checkForUpdates
    case checkingForUpdates
    case downloadUpdate
    case downloadingUpdate
    case openInstaller
    case updateAvailable
    case upToDate
    case updateUnknown
    case updateFailed
    case downloadedTo
    case releasePage
    case updateInstallNote
}

enum AppStrings {
    static func text(_ key: LocalizedKey, language: AppLanguage) -> String {
        switch language {
        case .japanese, .system:
            return japanese[key] ?? key.rawValue
        case .english:
            return english[key] ?? key.rawValue
        }
    }

    static func reason(_ value: String, language: AppLanguage) -> String {
        guard language == .english else { return value }
        return reasonEnglish[value] ?? value
    }

    private static let japanese: [LocalizedKey: String] = [
        .appSubtitle: "容量分析とセーフ整理",
        .safetyPolicy: "安全方針",
        .noAutomaticDelete: "自動削除なし",
        .confirmBeforeDelete: "削除前に確認ダイアログ",
        .moveToTrash: "操作はゴミ箱へ移動",
        .observeCannotDelete: "表示のみ項目は削除不可",
        .filter: "フィルター",
        .selectAll: "全選択",
        .clear: "解除",
        .scan: "スキャン",
        .scanning: "スキャン中",
        .trashConfirmTitle: "ゴミ箱へ移動しますか？",
        .cancel: "キャンセル",
        .trashMove: "ゴミ箱へ移動",
        .trashOneMessage: "%@ をゴミ箱へ移動します。完全削除ではありませんが、実ファイルに対する操作です。",
        .trashManyMessage: "%d件、合計 %@ をゴミ箱へ移動します。完全削除ではありませんが、実ファイルに対する操作です。",
        .storageMap: "容量マップ",
        .headerDescription: "大きいフォルダーを見つけ、詳細で使っている中身と整理候補を確認します。",
        .scanningMessage: "ファイルサイズを集計しています。削除や移動は行いません。",
        .waiting: "スキャン待機中",
        .waitingBody: "スキャン後にカテゴリ別の容量、確認対象、詳細がこの画面に表示されます。",
        .scanStart: "スキャン開始",
        .total: "合計",
        .unreadable: "読み取り不可",
        .targets: "確認対象",
        .detail: "詳細",
        .selectingTarget: "確認対象を選択",
        .selectTargetBody: "スキャン後に、容量を使っている中身と整理候補が表示されます。",
        .clickLeftItem: "左の項目をクリック",
        .clickLeftItemBody: "容量を使っているフォルダーや、Downloads内のdmg/pkgなどの整理候補を表示します。",
        .cleanupCandidates: "整理候補",
        .noCleanupCandidates: "この項目内にGUIからゴミ箱へ移動できる候補はありません。",
        .heavyContents: "容量を使っている中身",
        .noContents: "表示できる中身がありません。",
        .batchTrash: "まとめてゴミ箱",
        .file: "ファイル",
        .folder: "フォルダー",
        .settings: "設定",
        .language: "言語",
        .updates: "アップデート",
        .currentVersion: "現在のバージョン",
        .autoCheckUpdates: "起動時にアップデートを確認",
        .checkForUpdates: "アップデートを確認",
        .checkingForUpdates: "確認中",
        .downloadUpdate: "アップデートを取得",
        .downloadingUpdate: "取得中",
        .openInstaller: "取得したDMGを開く",
        .updateAvailable: "新しいバージョン %@ が利用できます。",
        .upToDate: "最新です。",
        .updateUnknown: "まだ確認していません。",
        .updateFailed: "アップデート確認に失敗しました。",
        .downloadedTo: "保存先: %@",
        .releasePage: "リリースページ",
        .updateInstallNote: "取得したDMGを開き、capacity-cleaning.appをApplicationsへドラッグすると更新を適用できます。"
    ]

    private static let english: [LocalizedKey: String] = [
        .appSubtitle: "Storage analysis and safe cleanup",
        .safetyPolicy: "Safety Policy",
        .noAutomaticDelete: "No automatic deletion",
        .confirmBeforeDelete: "Confirmation before deleting",
        .moveToTrash: "Files are moved to Trash",
        .observeCannotDelete: "View-only items cannot be deleted",
        .filter: "Filters",
        .selectAll: "Select All",
        .clear: "Clear",
        .scan: "Scan",
        .scanning: "Scanning",
        .trashConfirmTitle: "Move to Trash?",
        .cancel: "Cancel",
        .trashMove: "Move to Trash",
        .trashOneMessage: "Move %@ to Trash. This is a real file operation, although it is not permanent deletion.",
        .trashManyMessage: "Move %d items, %@ total, to Trash. This is a real file operation, although it is not permanent deletion.",
        .storageMap: "Storage Map",
        .headerDescription: "Find large folders, inspect their contents, and review cleanup candidates.",
        .scanningMessage: "Calculating file sizes. No files are deleted or moved.",
        .waiting: "Waiting to Scan",
        .waitingBody: "After scanning, category totals, review targets, and details appear here.",
        .scanStart: "Start Scan",
        .total: "Total",
        .unreadable: "Unreadable",
        .targets: "Targets",
        .detail: "Details",
        .selectingTarget: "Select a Target",
        .selectTargetBody: "After scanning, heavy contents and cleanup candidates will appear here.",
        .clickLeftItem: "Click an item on the left",
        .clickLeftItemBody: "Shows heavy folders and cleanup candidates such as dmg/pkg files in Downloads.",
        .cleanupCandidates: "Cleanup Candidates",
        .noCleanupCandidates: "No GUI-trashable candidates were found in this item.",
        .heavyContents: "Heavy Contents",
        .noContents: "No contents can be displayed.",
        .batchTrash: "Trash Selected",
        .file: "File",
        .folder: "Folder",
        .settings: "Settings",
        .language: "Language",
        .updates: "Updates",
        .currentVersion: "Current Version",
        .autoCheckUpdates: "Check for updates on launch",
        .checkForUpdates: "Check for Updates",
        .checkingForUpdates: "Checking",
        .downloadUpdate: "Download Update",
        .downloadingUpdate: "Downloading",
        .openInstaller: "Open Downloaded DMG",
        .updateAvailable: "Version %@ is available.",
        .upToDate: "You are up to date.",
        .updateUnknown: "Not checked yet.",
        .updateFailed: "Failed to check for updates.",
        .downloadedTo: "Saved to: %@",
        .releasePage: "Release Page",
        .updateInstallNote: "Open the downloaded DMG and drag capacity-cleaning.app to Applications to apply the update."
    ]

    private static let reasonEnglish: [String: String] = [
        "ダウンロード済みのインストーラ、動画、アーカイブが溜まりやすい場所です。": "Downloads often contains installers, videos, and archives that accumulate over time.",
        "大きい書類や作業フォルダを見つけるための表示です。": "Shows large documents and work folders for review.",
        "動画素材や画面収録が容量を使っている可能性があります。": "Video assets and screen recordings may be using significant space.",
        "写真ライブラリや画像素材の容量確認用です。": "Used to inspect photo libraries and image assets.",
        "アプリの設定やサポートデータが含まれるため、削除ではなく確認対象として扱います。": "Contains app settings and support data, so it is treated as a review target.",
        "アプリごとの保存データです。用途が分かるものだけ確認してください。": "Contains app-specific data. Review only items you understand.",
        "多くは再生成される一時データです。ブラウザ系は表示のみとして別扱いします。": "Mostly regenerated temporary data. Browser caches are handled separately as view-only.",
        "ブラウザキャッシュです。削除誘導はせず、容量と場所だけを表示します。": "Browser cache. The app only shows size and location, without deletion guidance.",
        "Xcodeが再生成するビルド生成物です。作業中プロジェクトがないか確認してください。": "Build artifacts regenerated by Xcode. Check active projects before removing.",
        "Simulatorの端末データやランタイムです。必要な端末がないか確認してください。": "Simulator device data and runtimes. Confirm you do not need them.",
        "npmのキャッシュ領域です。必要時に再取得されます。": "npm cache. It can be fetched again when needed.",
        "共有ライブラリやシステム寄りのデータです。容量把握のみを目的にします。": "Shared libraries and system-adjacent data. Shown for visibility only.",
        "大きいフォルダです。中身を確認して、不要なものだけ手動で整理してください。": "Large folder. Inspect contents and clean only what you do not need.",
        "Downloads内のインストーラ系ファイルです。インストール済みなら不要になっている可能性があります。": "Installer-style file in Downloads. It may be unnecessary if already installed.",
        "再生成されやすい領域の中身です。削除前にアプリが起動中でないことを確認してください。": "Content from an area that is often regenerated. Make sure related apps are not running.",
        "このフォルダーが親項目の容量を多く使っています。中身を確認してください。": "This folder uses a large share of the parent item. Inspect it before cleaning.",
        "サイズの大きいファイルです。用途を確認してください。": "Large file. Confirm what it is used for."
    ]
}
