import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let popover: NSPopover
    private let store: TaskStore
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []
    private var eventMonitor: EventMonitor?

    init(popover: NSPopover, store: TaskStore) {
        self.popover = popover
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        bindStore()
        configureEventMonitor()
    }

    deinit {
        eventMonitor?.stop()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageOnly
        button.toolTip = "Conductor"
        updateIcon()
    }

    private func bindStore() {
        store.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)
    }

    private func configureEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            if self.popover.isShown {
                self.popover.performClose(event)
            }
        }
        eventMonitor?.start()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbol = store.badgeSymbolName()
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Conductor status")
        button.image = image
        button.contentTintColor = store.badgeColor().nsColor
    }
}
