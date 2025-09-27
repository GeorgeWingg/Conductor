import AppKit
import SwiftUI

@main
struct ConductorFrontendMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?
    private var store: TaskStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = TaskStore(service: FakeTaskService())
        let contentView = ContentView()
            .environmentObject(store)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 380, height: 440)
        popover.contentViewController = NSHostingController(rootView: contentView)

        statusController = StatusBarController(popover: popover, store: store)
        Task { await store.loadInitial() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusController = nil
    }
}
