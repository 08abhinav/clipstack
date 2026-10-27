import AppKit
import ApplicationServices

/// Simulates ⌘V in the frontmost app. Requires Accessibility permission.
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt asking for permission if it has not been granted yet.
    @discardableResult
    static func requestPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func pasteIntoFrontApp() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
