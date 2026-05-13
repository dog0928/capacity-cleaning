import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updater: UpdateManager

    var body: some View {
        Form {
            Section(settings.t(.language)) {
                Picker(settings.t(.language), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(settings.t(.updates)) {
                LabeledContent(settings.t(.currentVersion), value: updater.currentVersion)

                Toggle(settings.t(.autoCheckUpdates), isOn: $settings.checksForUpdatesOnLaunch)

                Text(statusText)
                    .foregroundStyle(updater.statusKey == .updateFailed ? .red : .secondary)

                if let errorMessage = updater.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button {
                        Task { await updater.checkForUpdates() }
                    } label: {
                        Label(
                            updater.isChecking ? settings.t(.checkingForUpdates) : settings.t(.checkForUpdates),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(updater.isChecking)

                    Button {
                        Task { await updater.downloadUpdate() }
                    } label: {
                        Label(
                            updater.isDownloading ? settings.t(.downloadingUpdate) : settings.t(.downloadUpdate),
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(!updater.hasUpdate || updater.isDownloading)

                    Button {
                        updater.openDownloadedInstaller()
                    } label: {
                        Label(settings.t(.openInstaller), systemImage: "shippingbox")
                    }
                    .disabled(updater.downloadedDMG == nil)
                }

                if let downloadedDMG = updater.downloadedDMG {
                    Text(String(format: settings.t(.downloadedTo), downloadedDMG.path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Text(settings.t(.updateInstallNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    updater.openReleasePage()
                } label: {
                    Label(settings.t(.releasePage), systemImage: "safari")
                }
                .disabled(updater.latest == nil)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 620, height: 430)
    }

    private var statusText: String {
        if updater.statusKey == .updateAvailable, let latest = updater.latest {
            return String(format: settings.t(.updateAvailable), latest.version)
        }
        return settings.t(updater.statusKey)
    }
}
