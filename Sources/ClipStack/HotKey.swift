import Carbon

enum HotKeyOption: String, CaseIterable {
    case shiftCmdV
    case ctrlCmdV
    case ctrlShiftCmdV
    case optCmdV

    var title: String {
        switch self {
        case .shiftCmdV: return "⇧⌘V"
        case .ctrlCmdV: return "⌃⌘V"
        case .ctrlShiftCmdV: return "⌃⇧⌘V"
        case .optCmdV: return "⌥⌘V"
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .shiftCmdV: return UInt32(cmdKey | shiftKey)
        case .ctrlCmdV: return UInt32(cmdKey | controlKey)
        case .ctrlShiftCmdV: return UInt32(cmdKey | controlKey | shiftKey)
        case .optCmdV: return UInt32(cmdKey | optionKey)
        }
    }

    static var saved: HotKeyOption {
        get { UserDefaults.standard.string(forKey: "hotKey").flatMap(HotKeyOption.init) ?? .shiftCmdV }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "hotKey") }
    }
}

/// Global keyboard shortcut using the Carbon API (needs no permissions).
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    @discardableResult
    func register(_ option: HotKeyOption) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x434C_5053), id: 1) // "CLPS"
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_V), option.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }
}
