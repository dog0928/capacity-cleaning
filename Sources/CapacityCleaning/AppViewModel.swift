import AppKit
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var report: ScanReport?
    @Published var isScanning = false
    @Published var isLoadingDetail = false
    @Published var selectedLevels = Set(RecommendationLevel.allCases)
    @Published var selectedItem: ScanItem?
    @Published var selectedDetail: ItemDetail?
    @Published var selectedTrashEntryIDs = Set<String>()
    @Published var message = AppStrings.text(.waitingBody, language: .japanese)

    private let scanner = StorageScanner()
    private var language: AppLanguage = .japanese

    var filteredItems: [ScanItem] {
        guard let report else { return [] }
        return report.items.filter { selectedLevels.contains($0.level) }
    }

    var selectedTrashEntries: [DetailEntry] {
        guard let selectedDetail else { return [] }
        let allEntries = selectedDetail.cleanupCandidates + selectedDetail.heavyEntries
        var seen = Set<String>()
        return allEntries.filter { entry in
            guard selectedTrashEntryIDs.contains(entry.id), !seen.contains(entry.id) else {
                return false
            }
            seen.insert(entry.id)
            return true
        }
    }

    var selectedTrashBytes: Int64 {
        selectedTrashEntries.reduce(0) { $0 + $1.bytes }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        selectedItem = nil
        selectedDetail = nil
        selectedTrashEntryIDs.removeAll()
        message = tr(.scanningMessage)

        Task {
            let newReport = await scanner.scanHome()
            report = newReport
            isScanning = false
            message = language.resolved == .english
                ? "Scan complete: found \(newReport.items.count) review targets."
                : "スキャン完了: \(newReport.items.count)件の確認対象を見つけました。"
        }
    }

    func updateLanguage(_ newLanguage: AppLanguage) {
        language = newLanguage.resolved
        if report == nil, !isScanning, selectedDetail == nil {
            message = tr(.waitingBody)
        }
    }

    func toggleLevel(_ level: RecommendationLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    func selectAllLevels() {
        selectedLevels = Set(RecommendationLevel.allCases)
    }

    func clearLevels() {
        selectedLevels.removeAll()
    }

    func select(_ item: ScanItem) {
        selectedItem = item
        selectedDetail = nil
        selectedTrashEntryIDs.removeAll()
        isLoadingDetail = true
        message = language.resolved == .english
            ? "Inspecting \(item.name)."
            : "\(item.name) の中身を確認しています。"

        Task {
            let detail = await scanner.detail(for: item)
            guard selectedItem?.id == item.id else { return }
            selectedDetail = detail
            isLoadingDetail = false
            message = language.resolved == .english
                ? "Showing details for \(item.name)."
                : "\(item.name) の詳細を表示しています。"
        }
    }

    func reveal(_ item: ScanItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
    }

    func reveal(_ entry: DetailEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
    }

    func toggleTrashSelection(_ entry: DetailEntry) {
        guard canTrash(entry) else { return }
        if selectedTrashEntryIDs.contains(entry.id) {
            selectedTrashEntryIDs.remove(entry.id)
        } else {
            selectedTrashEntryIDs.insert(entry.id)
        }
    }

    func selectAllTrashCandidates() {
        guard let selectedDetail else { return }
        let allEntries = selectedDetail.cleanupCandidates + selectedDetail.heavyEntries
        selectedTrashEntryIDs = Set(allEntries.filter(canTrash).map(\.id))
    }

    func clearTrashSelection() {
        selectedTrashEntryIDs.removeAll()
    }

    func trash(_ entry: DetailEntry) {
        trash([entry])
    }

    func trash(_ entries: [DetailEntry]) {
        let targets = entries.filter(canTrash)
        guard !targets.isEmpty else {
            message = language.resolved == .english
                ? "No trashable items are selected."
                : "ゴミ箱へ移動できる項目が選択されていません。"
            return
        }

        var trashed: [DetailEntry] = []
        var failures: [String] = []

        for entry in targets {
            do {
                _ = try FileManager.default.trashItem(
                    at: URL(fileURLWithPath: entry.path),
                    resultingItemURL: nil
                )
                trashed.append(entry)
            } catch {
                failures.append("\(entry.name): \(error.localizedDescription)")
            }
        }

        removeTrashedEntries(trashed)

        if failures.isEmpty {
            message = language.resolved == .english
                ? "Moved \(trashed.count) items to Trash."
                : "\(trashed.count)件をゴミ箱へ移動しました。"
        } else {
            message = language.resolved == .english
                ? "Moved \(trashed.count) items to Trash; \(failures.count) failed."
                : "\(trashed.count)件をゴミ箱へ移動、\(failures.count)件は失敗しました。"
        }
    }

    func canTrash(_ entry: DetailEntry) -> Bool {
        entry.level != .observe
    }

    private func removeTrashedEntries(_ entries: [DetailEntry]) {
        guard let selectedDetail else { return }
        let removedIDs = Set(entries.map(\.id))
        selectedTrashEntryIDs.subtract(removedIDs)
        self.selectedDetail = ItemDetail(
            item: selectedDetail.item,
            heavyEntries: selectedDetail.heavyEntries.filter { !removedIDs.contains($0.id) },
            cleanupCandidates: selectedDetail.cleanupCandidates.filter { !removedIDs.contains($0.id) },
            unreadablePaths: selectedDetail.unreadablePaths
        )
    }

    private func tr(_ key: LocalizedKey) -> String {
        AppStrings.text(key, language: language.resolved)
    }
}
