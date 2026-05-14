import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updater: UpdateManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(settings.t(.settings))
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .help(settings.t(.close))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            Form {
                Section(settings.t(.language)) {
                    Picker(settings.t(.language), selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(settings.t(.safetyPolicy)) {
                    Text(settings.t(.safetyPolicyBody))
                        .foregroundStyle(.secondary)
                    SafetyPolicyLine(text: settings.t(.noAutomaticDelete))
                    SafetyPolicyLine(text: settings.t(.confirmBeforeDelete))
                    SafetyPolicyLine(text: settings.t(.moveToTrash))
                    SafetyPolicyLine(text: settings.t(.observeCannotDelete))
                }

                Section(settings.t(.updates)) {
                    LabeledContent(settings.t(.currentVersion), value: updater.installedBuildName)

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
                            Task { await updater.downloadAndApplyUpdate() }
                        } label: {
                            Label(
                                updateButtonTitle,
                                systemImage: "square.and.arrow.down.badge.checkmark"
                            )
                        }
                        .disabled(updater.latest?.isNewerThanCurrent == false || updater.isChecking || updater.isDownloading || updater.isApplying)
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
        }
        .frame(width: 660, height: 560)
    }

    private var statusText: String {
        if updater.statusKey == .updateAvailable, let latest = updater.latest {
            return String(format: settings.t(.updateAvailable), latest.releaseName)
        }
        return settings.t(updater.statusKey)
    }

    private var updateButtonTitle: String {
        if updater.isChecking {
            return settings.t(.checkingForUpdates)
        }
        if updater.isApplying {
            return settings.t(.applyingUpdate)
        }
        if updater.isDownloading {
            return settings.t(.downloadingUpdate)
        }
        return settings.t(.applyUpdate)
    }
}

private struct SafetyPolicyLine: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.secondary)
    }
}
