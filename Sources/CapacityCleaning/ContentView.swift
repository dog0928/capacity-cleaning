import Charts
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updater: UpdateManager
    @StateObject private var viewModel = AppViewModel()
    @State private var pendingTrashEntries: [DetailEntry] = []
    @State private var showsSettings = false
    @State private var didAutoCheckUpdates = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            dashboard
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.scan()
                } label: {
                    Label(viewModel.isScanning ? t(.scanning) : t(.scan), systemImage: "magnifyingglass")
                }
                .disabled(viewModel.isScanning)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(t(.settings))
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(updater)
        }
        .onAppear {
            viewModel.updateLanguage(settings.language)
            guard settings.checksForUpdatesOnLaunch, !didAutoCheckUpdates else { return }
            didAutoCheckUpdates = true
            Task { await updater.checkForUpdates() }
        }
        .onChange(of: settings.language) { _, newValue in
            viewModel.updateLanguage(newValue)
        }
        .alert(t(.trashConfirmTitle), isPresented: Binding(
            get: { !pendingTrashEntries.isEmpty },
            set: { isPresented in
                if !isPresented {
                    pendingTrashEntries.removeAll()
                }
            }
        )) {
            Button(t(.cancel), role: .cancel) {}
            Button(t(.trashMove), role: .destructive) {
                let entries = pendingTrashEntries
                pendingTrashEntries.removeAll()
                if !entries.isEmpty {
                    viewModel.trash(entries)
                }
            }
        } message: {
            Text(trashAlertMessage)
        }
    }

    private var trashAlertMessage: String {
        if pendingTrashEntries.count == 1 {
            return String(format: t(.trashOneMessage), pendingTrashEntries[0].name)
        }
        let bytes = pendingTrashEntries.reduce(Int64(0)) { $0 + $1.bytes }.formattedFileSize
        return String(format: t(.trashManyMessage), pendingTrashEntries.count, bytes)
    }

    private func t(_ key: LocalizedKey) -> String {
        settings.t(key)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("capacity-cleaning")
                    .font(.system(size: 26, weight: .bold))
                Text(t(.appSubtitle))
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t(.filter))
                        .font(.headline)
                    Spacer()
                    Button(t(.selectAll)) {
                        viewModel.selectAllLevels()
                    }
                    .buttonStyle(.plain)
                    Button(t(.clear)) {
                        viewModel.clearLevels()
                    }
                    .buttonStyle(.plain)
                }
                ForEach(RecommendationLevel.allCases) { level in
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedLevels.contains(level) },
                        set: { _ in viewModel.toggleLevel(level) }
                    )) {
                        HStack {
                            Circle()
                                .fill(level.badgeColor)
                                .frame(width: 8, height: 8)
                            Text(level.title(language: settings.language))
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Spacer()

            Text(viewModel.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 34)
        .padding(.bottom, 20)
        .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 330)
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if viewModel.isScanning {
                    scanningView
                }

                if let report = viewModel.report {
                    summary(report)
                    mainWorkArea(report)
                } else if !viewModel.isScanning {
                    welcomeOverview
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 42)
            .padding(.bottom, 26)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                headerTitle
                Spacer(minLength: 18)
                scanButton
            }

            VStack(alignment: .leading, spacing: 14) {
                headerTitle
                scanButton
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t(.storageMap))
                .font(.system(size: 34, weight: .bold))
            Text(t(.headerDescription))
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var scanButton: some View {
        Button {
            viewModel.scan()
        } label: {
            Label(viewModel.isScanning ? t(.scanning) : t(.scan), systemImage: "externaldrive.badge.magnifyingglass")
        }
        .controlSize(.large)
        .disabled(viewModel.isScanning)
    }

    private var scanningView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(t(.scanningMessage))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var welcomeOverview: some View {
        VStack(alignment: .leading, spacing: 18) {
            EmptySummaryPanel(scan: viewModel.scan)

            HStack(alignment: .top, spacing: 18) {
                EmptyListPanel()
                    .frame(minWidth: 430, idealWidth: 500, maxWidth: 560)
                EmptyDetailPanel()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func summary(_ report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline) {
                Text(t(.total))
                    .font(.title2.bold())
                Text(report.totalBytes.formattedFileSize)
                    .font(.system(size: 28, weight: .semibold))
                Spacer()
                Text("\(t(.unreadable)): \(report.unreadablePaths)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 18) {
                Chart(report.summaries) { summary in
                    SectorMark(
                        angle: .value("Storage", summary.bytes),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(summary.category.color)
                    .cornerRadius(5)
                }
                .chartLegend(.hidden)
                .frame(width: 250, height: 250)

                VStack(spacing: 10) {
                    ForEach(report.summaries) { summary in
                        CategoryRow(summary: summary)
                    }
                }
            }

            if let volumeInfo = report.volumeInfo {
                VolumeStoragePanel(info: volumeInfo)
            }
        }
    }

    private func mainWorkArea(_ report: ScanReport) -> some View {
        HStack(alignment: .top, spacing: 18) {
            candidateList(report)
                .frame(minWidth: 430, idealWidth: 500, maxWidth: 560)
            detailPanel
                .frame(maxWidth: .infinity)
        }
    }

    private func candidateList(_ report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(t(.targets))
                    .font(.title2.bold())
                Spacer()
                Text("\(viewModel.filteredItems.count) / \(report.items.count)")
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 10) {
                ForEach(viewModel.filteredItems) { item in
                    CandidateRow(
                        item: item,
                        isSelected: viewModel.selectedItem?.id == item.id,
                        select: { viewModel.select(item) },
                        reveal: { viewModel.reveal(item) }
                    )
                }
            }
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t(.detail))
                .font(.title2.bold())

            if viewModel.isLoadingDetail {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(t(.scanningMessage))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(18)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else if let detail = viewModel.selectedDetail {
                detailContent(detail)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 34))
                        .foregroundStyle(.teal)
                    Text(t(.clickLeftItem))
                        .font(.headline)
                    Text(t(.clickLeftItemBody))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func detailContent(_ detail: ItemDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(detail.item.name)
                        .font(.headline)
                    Text(detail.item.bytes.formattedFileSize)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.reveal(detail.item)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Finder")
                }
                Text(detail.item.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            DetailSection(
                title: t(.cleanupCandidates),
                isEmpty: detail.cleanupCandidates.isEmpty,
                emptyText: t(.noCleanupCandidates),
                headerAction: AnyView(batchTrashControls)
            ) {
                ForEach(detail.cleanupCandidates) { entry in
                    DetailEntryRow(
                        entry: entry,
                        showsTrash: true,
                        canTrash: viewModel.canTrash(entry),
                        isSelected: viewModel.selectedTrashEntryIDs.contains(entry.id)
                    ) {
                        viewModel.toggleTrashSelection(entry)
                    } reveal: {
                        viewModel.reveal(entry)
                    } trash: {
                        pendingTrashEntries = [entry]
                    }
                }
            }

            DetailSection(
                title: t(.heavyContents),
                isEmpty: detail.heavyEntries.isEmpty,
                emptyText: t(.noContents)
            ) {
                ForEach(detail.heavyEntries) { entry in
                    DetailEntryRow(
                        entry: entry,
                        showsTrash: viewModel.canTrash(entry),
                        canTrash: viewModel.canTrash(entry),
                        isSelected: viewModel.selectedTrashEntryIDs.contains(entry.id)
                    ) {
                        viewModel.toggleTrashSelection(entry)
                    } reveal: {
                        viewModel.reveal(entry)
                    } trash: {
                        pendingTrashEntries = [entry]
                    }
                }
            }

            if detail.unreadablePaths > 0 {
                Text("\(t(.unreadable)): \(detail.unreadablePaths)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var batchTrashControls: some View {
        HStack(spacing: 10) {
            Text(settings.language.resolved == .english
                ? "\(viewModel.selectedTrashEntries.count) items / \(viewModel.selectedTrashBytes.formattedFileSize)"
                : "\(viewModel.selectedTrashEntries.count)件 / \(viewModel.selectedTrashBytes.formattedFileSize)"
            )
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(t(.selectAll)) {
                viewModel.selectAllTrashCandidates()
            }
            .buttonStyle(.plain)
            Button(t(.clear)) {
                viewModel.clearTrashSelection()
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
                pendingTrashEntries = viewModel.selectedTrashEntries
            } label: {
                Label(t(.batchTrash), systemImage: "trash")
            }
            .disabled(viewModel.selectedTrashEntries.isEmpty)
        }
    }
}

private struct SafetyRow: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }
}

private struct EmptySummaryPanel: View {
    @EnvironmentObject private var settings: AppSettings
    let scan: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 22)
                Image(systemName: "chart.pie")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.teal)
            }
            .frame(width: 210, height: 210)

            VStack(alignment: .leading, spacing: 14) {
                Text(settings.t(.waiting))
                    .font(.title2.bold())
                Text(settings.t(.waitingBody))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: scan) {
                    Label(settings.t(.scanStart), systemImage: "play.fill")
                }
                .controlSize(.large)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .leading)
        .padding(18)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EmptyListPanel: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(settings.t(.targets))
                    .font(.title2.bold())
                Spacer()
                Text("0 / 0")
                    .foregroundStyle(.secondary)
            }

            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.quaternary)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)
                            .frame(width: 180, height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)
                            .frame(maxWidth: .infinity, minHeight: 10, maxHeight: 10)
                    }
                }
                .padding(14)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
        }
    }
}

private struct EmptyDetailPanel: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.t(.detail))
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 32))
                    .foregroundStyle(.teal)
                Text(settings.t(.selectingTarget))
                    .font(.headline)
                Text(settings.t(.selectTargetBody))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
            .padding(18)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct VolumeStoragePanel: View {
    @EnvironmentObject private var settings: AppSettings
    let info: VolumeStorageInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(settings.t(.hiddenSystemData))
                    .font(.headline)
                Spacer()
                Text("\(settings.t(.hiddenSystemDataEstimate)): \(info.hiddenSystemBytes.formattedFileSize)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let usedWidth = barWidth(bytes: info.usedBytes, total: info.totalBytes, width: width)
                let explainedWidth = barWidth(bytes: info.explainedBytes, total: info.totalBytes, width: width)
                let hiddenWidth = barWidth(bytes: info.hiddenSystemBytes, total: info.totalBytes, width: width)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.28))
                        .frame(width: usedWidth)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.teal.opacity(0.75))
                        .frame(width: explainedWidth)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.purple.opacity(0.82))
                        .frame(width: hiddenWidth)
                        .offset(x: explainedWidth)
                }
            }
            .frame(height: 12)

            HStack(spacing: 10) {
                StorageMetric(title: settings.t(.diskUsed), value: info.usedBytes.formattedFileSize, color: .gray)
                StorageMetric(title: settings.t(.visualized), value: info.explainedBytes.formattedFileSize, color: .teal)
                StorageMetric(title: settings.t(.hiddenSystemData), value: info.hiddenSystemBytes.formattedFileSize, color: .purple)
                StorageMetric(title: settings.t(.diskAvailable), value: info.availableBytes.formattedFileSize, color: .green)
            }

            Text(settings.t(.hiddenSystemDataBody))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func barWidth(bytes: Int64, total: Int64, width: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return max(0, min(width, width * CGFloat(Double(bytes) / Double(total))))
    }
}

private struct StorageMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CategoryRow: View {
    @EnvironmentObject private var settings: AppSettings
    let summary: CategorySummary

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(summary.category.color)
                .frame(width: 12, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(summary.category.title(language: settings.language))
                        .font(.headline)
                    Spacer()
                    Text(summary.bytes.formattedFileSize)
                        .font(.headline)
                }
                Text(summary.category.note(language: settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CandidateRow: View {
    @EnvironmentObject private var settings: AppSettings
    let item: ScanItem
    let isSelected: Bool
    let select: () -> Void
    let reveal: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(item.category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.bytes.formattedFileSize)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    LevelBadge(level: item.level)
                }

                Text(settings.reason(item.reason))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button(action: reveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .help("Finder")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .padding(14)
        .background(isSelected ? item.category.color.opacity(0.14) : Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? item.category.color.opacity(0.55) : Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch item.category {
        case .userFiles: return "doc.on.doc"
        case .userLibrary: return "books.vertical"
        case .caches: return "tray.full"
        case .developer: return "hammer"
        case .system: return "gearshape.2"
        case .systemDataEstimate: return "internaldrive"
        case .other: return "folder"
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let isEmpty: Bool
    let emptyText: String
    var headerAction: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                headerAction
            }
            if isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else {
                content
            }
        }
    }
}

private struct DetailEntryRow: View {
    @EnvironmentObject private var settings: AppSettings
    let entry: DetailEntry
    let showsTrash: Bool
    let canTrash: Bool
    let isSelected: Bool
    let toggleSelection: () -> Void
    let reveal: () -> Void
    let trash: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsTrash {
                Toggle(isOn: Binding(
                    get: { isSelected },
                    set: { _ in toggleSelection() }
                )) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!canTrash)
                .help(settings.t(.batchTrash))
            }

            Image(systemName: entry.kind == .folder ? "folder" : "doc")
                .font(.title3)
                .foregroundStyle(entry.level.badgeColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(entry.bytes.formattedFileSize)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    LevelBadge(level: entry.level)
                }

                Text(settings.reason(entry.reason))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(entry.kind == .folder ? settings.t(.folder) : settings.t(.file))
                    if let modifiedAt = entry.modifiedAt {
                        Text(modifiedAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    Text(entry.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Button(action: reveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .help("Finder")

            if showsTrash {
                Button(role: .destructive, action: trash) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!canTrash)
                .help(settings.t(.trashMove))
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

private struct LevelBadge: View {
    @EnvironmentObject private var settings: AppSettings
    let level: RecommendationLevel

    var body: some View {
        Text(level.title(language: settings.language))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(level.badgeColor)
            .background(level.badgeColor.opacity(0.12), in: Capsule())
    }
}
