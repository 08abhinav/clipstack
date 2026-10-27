import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = HistoryStore()
    private lazy var monitor = ClipboardMonitor(store: store)
    private lazy var panel = PanelController(store: store)
    private lazy var screenshots = ScreenshotWatcher { [weak self] url in self?.importScreenshot(url) }
    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!

    private var hotKeyOption = HotKeyOption.saved
    private var captureScreenshots: Bool {
        get { UserDefaults.standard.object(forKey: "captureScreenshots") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "captureScreenshots") }
    }
    private var autoPaste: Bool {
        get { UserDefaults.standard.object(forKey: "autoPaste") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoPaste") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = StatusIcon.make()
        statusItem.button?.image?.accessibilityDescription = "ClipStack"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        hotKey = HotKey { [weak self] in
            guard let self else { return }
            self.panel.toggle(hotKeyTitle: self.hotKeyOption.title)
        }
        registerHotKey()

        panel.onPick = { [weak self] item in self?.paste(item) }

        monitor.start()
        if captureScreenshots { screenshots.start() }

        if autoPaste && !Paster.isTrusted {
            Paster.requestPermission()
        }
    }

    // MARK: - Pasting

    private func paste(_ item: ClipItem) {
        store.write(item)
        monitor.ignoreCurrentContents()
        store.moveToTop(id: item.id)

        guard autoPaste else { return }
        guard Paster.isTrusted else {
            Paster.requestPermission()
            return
        }
        // Short delay so the panel closes and focus returns to the target app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Paster.pasteIntoFrontApp()
        }
    }

    private func importScreenshot(_ url: URL) {
        // The file may take a moment to be fully written.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.monitor.isPaused, let data = try? Data(contentsOf: url) else { return }
            self.store.addImage(data: data, sourceApp: nil, isScreenshot: true)
        }
    }

    private func registerHotKey() {
        if !hotKey.register(hotKeyOption) {
            let alert = NSAlert()
            alert.messageText = L("alert.hotKeyFailed.title", hotKeyOption.title)
            alert.informativeText = L("alert.hotKeyFailed.body")
            alert.runModal()
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item(L("menu.show", hotKeyOption.title), #selector(showPanel)))
        menu.addItem(.separator())

        let hotKeyMenu = NSMenu()
        for option in HotKeyOption.allCases {
            let entry = item(option.title, #selector(selectHotKey(_:)))
            entry.representedObject = option.rawValue
            entry.state = option == hotKeyOption ? .on : .off
            hotKeyMenu.addItem(entry)
        }
        let hotKeyItem = NSMenuItem(title: L("menu.hotKey"), action: nil, keyEquivalent: "")
        hotKeyItem.submenu = hotKeyMenu
        menu.addItem(hotKeyItem)

        let limitMenu = NSMenu()
        for limit in [50, 100, 200, 500, 1000] {
            let entry = item(L("menu.items", limit), #selector(selectLimit(_:)))
            entry.tag = limit
            entry.state = limit == store.maxItems ? .on : .off
            limitMenu.addItem(entry)
        }
        let limitItem = NSMenuItem(title: L("menu.historySize"), action: nil, keyEquivalent: "")
        limitItem.submenu = limitMenu
        menu.addItem(limitItem)

        let languageMenu = NSMenu()
        for language in AppLanguage.allCases {
            let entry = item(language.displayName, #selector(selectLanguage(_:)))
            entry.representedObject = language.rawValue
            entry.state = language == AppLanguage.current ? .on : .off
            languageMenu.addItem(entry)
            if language == .system { languageMenu.addItem(.separator()) }
        }
        let languageItem = NSMenuItem(title: L("menu.language"), action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        menu.addItem(.separator())

        menu.addItem(toggle(L("menu.captureScreenshots"), captureScreenshots, #selector(toggleScreenshots)))
        menu.addItem(toggle(L("menu.autoPaste"), autoPaste, #selector(toggleAutoPaste)))
        menu.addItem(toggle(L("menu.launchAtLogin"), SMAppService.mainApp.status == .enabled, #selector(toggleLoginItem)))
        menu.addItem(toggle(L("menu.pause"), monitor.isPaused, #selector(togglePause)))

        if autoPaste && !Paster.isTrusted {
            menu.addItem(.separator())
            menu.addItem(item(L("menu.grantAccessibility"), #selector(openAccessibility)))
        }

        menu.addItem(.separator())
        menu.addItem(item(L("menu.clearHistory"), #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(item(L("menu.quit"), #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        return entry
    }

    private func toggle(_ title: String, _ isOn: Bool, _ action: Selector) -> NSMenuItem {
        let entry = item(title, action)
        entry.state = isOn ? .on : .off
        return entry
    }

    @objc private func showPanel() {
        panel.show(hotKeyTitle: hotKeyOption.title)
    }

    @objc private func selectHotKey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let option = HotKeyOption(rawValue: raw) else { return }
        hotKeyOption = option
        HotKeyOption.saved = option
        registerHotKey()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = AppLanguage(rawValue: raw) else { return }
        AppLanguage.current = language
    }

    @objc private func selectLimit(_ sender: NSMenuItem) {
        store.maxItems = sender.tag
    }

    @objc private func toggleScreenshots() {
        captureScreenshots.toggle()
        captureScreenshots ? screenshots.start() : screenshots.stop()
    }

    @objc private func toggleAutoPaste() {
        autoPaste.toggle()
        if autoPaste && !Paster.isTrusted { Paster.requestPermission() }
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func togglePause() {
        monitor.isPaused.toggle()
        statusItem.button?.appearsDisabled = monitor.isPaused
    }

    @objc private func openAccessibility() {
        Paster.requestPermission()
        Paster.openAccessibilitySettings()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = L("alert.clear.title")
        alert.informativeText = L("alert.clear.body")
        alert.addButton(withTitle: L("alert.clear.confirm"))
        alert.addButton(withTitle: L("alert.cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.clear()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
