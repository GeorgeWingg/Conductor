import SwiftUI

@main
struct ConductorFrontendApp: App {
    @StateObject private var store = TaskStore(service: FakeTaskService())

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            MenuBarIconView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
