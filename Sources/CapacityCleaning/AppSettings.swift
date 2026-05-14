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
    case safetyPolicyBody
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
    case diskUsed
    case diskAvailable
    case visualized
    case hiddenSystemData
    case hiddenSystemDataBody
    case hiddenSystemDataEstimate
    case systemDataBreakdown
    case deletableSystemData
    case dangerousSystemData
    case dangerousSystemDataBody
    case systemDataDeleteNote
    case deletable
    case notDeletable
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
    case applyUpdate
    case applyingUpdate
    case updateAvailable
    case upToDate
    case updateUnknown
    case updateFailed
    case downloadedTo
    case releasePage
    case updateInstallNote
    case close
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
        .safetyPolicyBody: "capacity-cleaningは自動削除を行いません。ファイル操作はユーザーが削除ボタンを押し、確認ダイアログで承認した場合だけ実行されます。",
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
        .diskUsed: "ディスク使用量",
        .diskAvailable: "空き容量",
        .visualized: "分類できた容量",
        .hiddenSystemData: "見えないシステムデータ",
        .hiddenSystemDataBody: "ディスク使用量から、このアプリが分類できた容量を差し引いた推定値です。APFSスナップショット、ローカルバックアップ、仮想メモリ、Spotlightインデックス、権限で読めない領域などが含まれる可能性があります。",
        .hiddenSystemDataEstimate: "推定値",
        .systemDataBreakdown: "システムデータの内訳",
        .deletableSystemData: "削除できる可能性がある項目",
        .dangerousSystemData: "削除すると危険な項目",
        .dangerousSystemDataBody: "これらは容量として見えることがありますが、OSの復元、起動、メモリ管理、検索インデックス、バックアップに関わるため、このアプリでは削除対象にしません。",
        .systemDataDeleteNote: "削除候補は確認対象にも表示されます。クリックして詳細を開き、チェックマークで選択してゴミ箱へ移動できます。",
        .deletable: "削除候補",
        .notDeletable: "削除不可",
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
        .currentVersion: "インストール済みビルド",
        .autoCheckUpdates: "起動時にアップデートを確認",
        .checkForUpdates: "アップデートを確認",
        .checkingForUpdates: "確認中",
        .downloadUpdate: "アップデートを取得",
        .downloadingUpdate: "取得中",
        .openInstaller: "取得したDMGを開く",
        .applyUpdate: "アップデートを適用",
        .applyingUpdate: "適用中",
        .updateAvailable: "新しいバージョン %@ が利用できます。",
        .upToDate: "最新です。",
        .updateUnknown: "まだ確認していません。",
        .updateFailed: "アップデート確認に失敗しました。",
        .downloadedTo: "保存先: %@",
        .releasePage: "リリースページ",
        .updateInstallNote: "「アップデートを適用」を押すと、DMGを取得して自動でアプリを置き換え、更新版を起動します。",
        .close: "閉じる"
    ]

    private static let english: [LocalizedKey: String] = [
        .appSubtitle: "Storage analysis and safe cleanup",
        .safetyPolicy: "Safety Policy",
        .safetyPolicyBody: "capacity-cleaning never performs automatic deletion. File operations only run after the user clicks a Trash button and confirms the dialog.",
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
        .diskUsed: "Disk Used",
        .diskAvailable: "Available",
        .visualized: "Visualized",
        .hiddenSystemData: "Hidden System Data",
        .hiddenSystemDataBody: "Estimated by subtracting the storage this app could classify from total disk usage. It may include APFS snapshots, local backups, virtual memory, Spotlight indexes, and areas blocked by permissions.",
        .hiddenSystemDataEstimate: "Estimate",
        .systemDataBreakdown: "System Data Breakdown",
        .deletableSystemData: "Potentially Deletable Items",
        .dangerousSystemData: "Dangerous to Delete",
        .dangerousSystemDataBody: "These can appear as storage usage, but they are tied to OS recovery, booting, memory management, search indexing, and backups, so this app does not offer them for deletion.",
        .systemDataDeleteNote: "Deletable candidates also appear in Targets. Click one, review Details, select entries with checkmarks, then move them to Trash.",
        .deletable: "Candidate",
        .notDeletable: "Protected",
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
        .currentVersion: "Installed Build",
        .autoCheckUpdates: "Check for updates on launch",
        .checkForUpdates: "Check for Updates",
        .checkingForUpdates: "Checking",
        .downloadUpdate: "Download Update",
        .downloadingUpdate: "Downloading",
        .openInstaller: "Open Downloaded DMG",
        .applyUpdate: "Apply Update",
        .applyingUpdate: "Applying",
        .updateAvailable: "Version %@ is available.",
        .upToDate: "You are up to date.",
        .updateUnknown: "Not checked yet.",
        .updateFailed: "Failed to check for updates.",
        .downloadedTo: "Saved to: %@",
        .releasePage: "Release Page",
        .updateInstallNote: "Apply Update downloads the DMG, replaces the app automatically, and opens the updated version.",
        .close: "Close"
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
        "サイズの大きいファイルです。用途を確認してください。": "Large file. Confirm what it is used for.",
        "スナップショット、仮想メモリ、インデックス、読み取り不可領域などの推定差分です。": "Estimated difference from snapshots, virtual memory, indexes, unreadable areas, and other hidden system data.",
        "ユーザーのログです。古いログは削除しても再作成されますが、直近のトラブル調査に使う場合があります。": "User logs. Older logs are usually recreated, but recent ones may be useful for troubleshooting.",
        "iPhoneやiPadのローカルバックアップです。削除するとそのバックアップから復元できなくなるため、必要性を確認してください。": "Local iPhone or iPad backups. If removed, you cannot restore from that backup, so confirm it is no longer needed.",
        "システムデータの推定差分です。読み取り不可領域やOS管理データが混ざるため、直接削除できる1つのフォルダーとして扱えません。": "Estimated hidden system data. It can include unreadable areas and OS-managed data, so it cannot be treated as one deletable folder.",
        "APFSスナップショットやローカルTime Machineは復元とバックアップ整合性に関わります。通常のフォルダーではないため、このアプリでは削除対象にしません。": "APFS snapshots and local Time Machine data affect recovery and backup consistency. They are not normal folders, so this app does not offer them for deletion.",
        "仮想メモリとスリープ関連ファイルです。起動中のmacOSが使うため、手動削除すると不安定化やデータ損失につながる可能性があります。": "Virtual memory and sleep files are used by macOS while running. Manual deletion can cause instability or data loss.",
        "macOS本体とシステム保護領域です。削除すると起動不能やアップデート失敗につながるため対象外です。": "macOS system and protected areas. Deleting them can prevent booting or break updates, so they are excluded.",
        "Spotlightの検索インデックスです。削除すると検索やメタデータ処理が壊れたり、再構築で一時的に負荷が上がるため対象外です。": "Spotlight search indexes. Removing them can break search and metadata behavior or trigger heavy rebuild work, so they are excluded.",
        "共有フレームワーク、拡張、ドライバ、アプリ共通データが含まれます。依存関係が分かりにくいため削除対象外です。": "Shared frameworks, extensions, drivers, and app-wide support data. Dependencies are hard to verify, so they are excluded.",
        "アプリのウィンドウ復元や終了時状態です。削除すると一部アプリの復元状態は消えますが、必要に応じて再作成されます。": "Saved window and app restore state. Removing it clears some restore state, but apps recreate it as needed.",
        "クラッシュログや診断レポートです。古いものは削除できますが、直近の不具合調査に使う場合があります。": "Crash logs and diagnostic reports. Older reports can be removed, but recent ones may be useful for troubleshooting.",
        "接続したiPhoneやiPad用にXcodeが保存したサポートデータです。古いOS端末を使わない場合は削除候補になります。": "Xcode support data for connected iPhone or iPad devices. It is a cleanup candidate when you no longer use devices on those older OS versions.",
        "Xcodeの配布用アーカイブです。削除すると再アップロードや再署名に必要な履歴を失う可能性があります。不要なものだけ確認してください。": "Xcode distribution archives. Removing them can lose history needed for re-uploading or re-signing, so clean only items you no longer need.",
        "Simulatorが作るキャッシュです。削除後に必要なデータは再生成されますが、SimulatorやXcodeを終了してから操作してください。": "Caches created by Simulator. Needed data is regenerated after removal, but quit Simulator and Xcode before cleaning.",
        "macOSがユーザーごとに割り当てる一時フォルダーです。起動中アプリが使っている可能性があるため、古い項目だけ確認してください。": "Per-user temporary folder assigned by macOS. Running apps may still use it, so review old items only.",
        "macOSのユーザー別キャッシュ領域です。多くは再生成されますが、実行中アプリのデータがないか確認してください。": "Per-user macOS cache area. Most data is regenerated, but check for files used by running apps.",
        "アプリやWebViewが保存するHTTPデータです。ログイン状態やオフラインデータに関係する場合があるため確認対象です。": "HTTP data stored by apps and WebViews. It can affect login state or offline data, so review it first.",
        "全ユーザー共通のキャッシュです。権限や依存関係があるため、容量把握のみ行います。": "System-wide cache shared by all users. It is shown for visibility because permissions and dependencies may apply.",
        "全ユーザー共通のログです。原因調査や管理者権限に関わるため、容量把握のみ行います。": "System-wide logs shared by all users. They are shown for visibility because they may be needed for diagnostics or require admin permissions.",
        "macOSアップデート用データです。削除するとアップデートや復旧に影響する可能性があるため表示のみです。": "macOS update data. It is view-only because removing it can affect updates or recovery.",
        "インストール済みアプリ本体です。不要なアプリや巨大なアプリを確認するための表示です。": "Installed applications. Review this to find unused or unusually large apps.",
        "アプリコンテナ内のキャッシュです。アプリ終了後なら再生成されやすい領域ですが、対象アプリ名を確認してください。": "Cache inside an app container. It is usually regenerated after quitting the app, but confirm which app owns it.",
        "QuickLookのサムネイルキャッシュです。必要に応じて再生成されるため削除候補になります。": "QuickLook thumbnail cache. It is regenerated when needed, so it is a cleanup candidate.",
        "メッセージの添付ファイルです。削除すると会話内の添付を失う可能性があるため、不要なものだけ確認してください。": "Messages attachments. Removing them can remove attachments from conversations, so clean only items you do not need.",
        "メールから開いた添付ファイルの保存領域です。必要な添付を別保存している場合は削除候補になります。": "Storage for attachments opened from Mail. It is a cleanup candidate if needed attachments were saved elsewhere.",
        "iPhoneやiPadのアップデートファイルです。必要になれば再取得できるため削除候補になります。": "iPhone and iPad update files. They can be downloaded again when needed, so they are cleanup candidates.",
        "Xcodeが保存した実機デバイスログです。古いログは削除候補になります。": "Device logs saved by Xcode. Older logs are cleanup candidates.",
        "SwiftUI Previews用のSimulatorデータです。Xcodeを終了してから不要なものを確認してください。": "Simulator data for SwiftUI Previews. Quit Xcode first, then review unneeded items.",
        "Swift Package Managerのキャッシュです。必要時に再取得されます。": "Swift Package Manager cache. It can be fetched again when needed.",
        "Homebrewのダウンロードキャッシュです。必要時に再取得できます。": "Homebrew download cache. It can be fetched again when needed.",
        "Python pipのキャッシュです。必要時に再取得されます。": "Python pip cache. It can be fetched again when needed.",
        "Gradleの依存関係キャッシュです。ビルド時に再取得されます。": "Gradle dependency cache. It is downloaded again during builds.",
        "Mavenのローカル依存関係リポジトリです。再取得できますが、次回ビルド時間が増える可能性があります。": "Maven local dependency repository. It can be downloaded again, but the next build may take longer.",
        "Rust Cargoのレジストリキャッシュです。必要時に再取得されます。": "Rust Cargo registry cache. It can be fetched again when needed."
    ]
}
