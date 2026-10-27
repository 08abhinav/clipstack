import AppKit
import SwiftUI

/// Floating panel that does not activate the app, so the app you came from
/// stays frontmost and receives the paste.
final class ClipPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    private let store: HistoryStore
    private let state = PanelState()
    private let panel: ClipPanel
    private let hostingView: NSHostingView<HistoryView>
    private var keyMonitor: Any?

    /// Called with the chosen item after the panel closes.
    var onPick: ((ClipItem) -> Void)?

    var isVisible: Bool { panel.isVisible }

    init(store: HistoryStore) {
        self.store = store
        panel = ClipPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        hostingView = NSHostingView(rootView: HistoryView(store: store, state: state, hotKeyTitle: "", onPick: { _ in }))
        super.init()

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.minSize = NSSize(width: 380, height: 300)
        panel.delegate = self

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        panel.contentView = background

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: background.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func toggle(hotKeyTitle: String) {
        isVisible ? hide() : show(hotKeyTitle: hotKeyTitle)
    }

    func show(hotKeyTitle: String) {
        hostingView.rootView = HistoryView(store: store, state: state, hotKeyTitle: hotKeyTitle) { [weak self] item in
            self?.pick(item)
        }
        state.query = ""
        state.selection = 0
        state.openCount += 1

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = panel.frame.size
            let origin = NSPoint(x: visible.midX - size.width / 2,
                                 y: visible.midY - size.height / 2 + visible.height * 0.08)
            panel.setFrameOrigin(origin)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Keyboard

    private var visibleItems: [ClipItem] { store.filtered(state.query) }

    private func handle(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 125: // ↓
            moveSelection(by: 1); return true
        case 126: // ↑
            moveSelection(by: -1); return true
        case 116: // page up
            moveSelection(by: -8); return true
        case 121: // page down
            moveSelection(by: 8); return true
        case 36, 76: // return, enter
            pickSelected(); return true
        case 53: // esc
            hide(); return true
        case 51 where command: // ⌘⌫
            deleteSelected(); return true
        default:
            if command, let chars = event.charactersIgnoringModifiers,
               let number = Int(chars), (1...9).contains(number) {
                let items = visibleItems
                if items.indices.contains(number - 1) { pick(items[number - 1]) }
                return true
            }
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        let count = visibleItems.count
        guard count > 0 else { return }
        state.selection = min(max(state.selection + delta, 0), count - 1)
    }

    private func pickSelected() {
        let items = visibleItems
        guard items.indices.contains(state.selection) else { return }
        pick(items[state.selection])
    }

    private func deleteSelected() {
        let items = visibleItems
        guard items.indices.contains(state.selection) else { return }
        store.remove(id: items[state.selection].id)
        state.selection = min(state.selection, max(visibleItems.count - 1, 0))
    }

    private func pick(_ item: ClipItem) {
        hide()
        onPick?(item)
    }
}
