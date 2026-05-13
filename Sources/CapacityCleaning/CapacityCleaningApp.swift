import SwiftUI

@main
struct CapacityCleaningApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var updater = UpdateManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(updater)
                .frame(minWidth: 1040, minHeight: 720)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(updater)
        }
    }
}
