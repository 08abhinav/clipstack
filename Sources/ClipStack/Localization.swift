import Foundation

/// Languages the user can pick from the menu. `system` follows macOS preferences.
enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case spanish = "es"
    case chinese = "zh-Hans"
    case hindi = "hi"

    /// Each language is shown in its own name so anyone can find theirs.
    var displayName: String {
        switch self {
        case .system: return L("language.system")
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "简体中文"
        case .hindi: return "हिन्दी"
        }
    }

    var locale: Locale { Locale(identifier: AppLanguage.resolved.rawValue) }

    static var current: AppLanguage {
        get { UserDefaults.standard.string(forKey: "language").flatMap(AppLanguage.init) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "language") }
    }

    /// The concrete language in use, resolving `system` against the macOS language list.
    static var resolved: AppLanguage {
        if current != .system { return current }
        for preferred in Locale.preferredLanguages {
            if preferred.hasPrefix("es") { return .spanish }
            if preferred.hasPrefix("zh") { return .chinese }
            if preferred.hasPrefix("hi") { return .hindi }
            if preferred.hasPrefix("en") { return .english }
        }
        return .english
    }
}

/// Returns the translated string for `key`, formatting it with `args` when given.
func L(_ key: String, _ args: CVarArg...) -> String {
    let language = AppLanguage.resolved
    let format = Strings.table[key]?[language] ?? Strings.table[key]?[.english] ?? key
    return args.isEmpty ? format : String(format: format, locale: language.locale, arguments: args)
}

private enum Strings {
    static let table: [String: [AppLanguage: String]] = [
        // Panel
        "search.placeholder": [
            .english: "Search clipboard…",
            .spanish: "Buscar en el portapapeles…",
            .chinese: "搜索剪贴板…",
            .hindi: "क्लिपबोर्ड में खोजें…",
        ],
        "empty.none": [
            .english: "You haven't copied anything yet",
            .spanish: "Aún no has copiado nada",
            .chinese: "你还没有复制任何内容",
            .hindi: "आपने अभी तक कुछ कॉपी नहीं किया है",
        ],
        "empty.noResults": [
            .english: "No results",
            .spanish: "Sin resultados",
            .chinese: "没有结果",
            .hindi: "कोई परिणाम नहीं",
        ],
        "footer.navigate": [
            .english: "↑↓ navigate",
            .spanish: "↑↓ navegar",
            .chinese: "↑↓ 选择",
            .hindi: "↑↓ चुनें",
        ],
        "footer.paste": [
            .english: "↩ paste",
            .spanish: "↩ pegar",
            .chinese: "↩ 粘贴",
            .hindi: "↩ पेस्ट करें",
        ],
        "footer.quick": [
            .english: "⌘1–9 quick paste",
            .spanish: "⌘1–9 rápido",
            .chinese: "⌘1–9 快速粘贴",
            .hindi: "⌘1–9 तुरंत",
        ],
        "footer.delete": [
            .english: "⌘⌫ delete",
            .spanish: "⌘⌫ borrar",
            .chinese: "⌘⌫ 删除",
            .hindi: "⌘⌫ हटाएँ",
        ],

        // Rows
        "row.imageUnavailable": [
            .english: "Image unavailable",
            .spanish: "Imagen no disponible",
            .chinese: "图片不可用",
            .hindi: "छवि उपलब्ध नहीं है",
        ],
        "row.characters": [
            .english: "%d characters",
            .spanish: "%d caracteres",
            .chinese: "%d 个字符",
            .hindi: "%d अक्षर",
        ],
        "row.screenshot": [
            .english: "Screenshot",
            .spanish: "Captura de pantalla",
            .chinese: "截图",
            .hindi: "स्क्रीनशॉट",
        ],
        "row.oneFile": [
            .english: "1 file",
            .spanish: "1 archivo",
            .chinese: "1 个文件",
            .hindi: "1 फ़ाइल",
        ],
        "row.files": [
            .english: "%d files",
            .spanish: "%d archivos",
            .chinese: "%d 个文件",
            .hindi: "%d फ़ाइलें",
        ],

        // Menu
        "menu.show": [
            .english: "Show history (%@)",
            .spanish: "Mostrar historial (%@)",
            .chinese: "显示历史记录（%@）",
            .hindi: "इतिहास दिखाएँ (%@)",
        ],
        "menu.hotKey": [
            .english: "Keyboard shortcut",
            .spanish: "Atajo de teclado",
            .chinese: "键盘快捷键",
            .hindi: "कीबोर्ड शॉर्टकट",
        ],
        "menu.historySize": [
            .english: "History size",
            .spanish: "Tamaño del historial",
            .chinese: "历史记录大小",
            .hindi: "इतिहास का आकार",
        ],
        "menu.items": [
            .english: "%d items",
            .spanish: "%d elementos",
            .chinese: "%d 项",
            .hindi: "%d आइटम",
        ],
        "menu.captureScreenshots": [
            .english: "Save screenshots",
            .spanish: "Guardar capturas de pantalla",
            .chinese: "保存截图",
            .hindi: "स्क्रीनशॉट सहेजें",
        ],
        "menu.autoPaste": [
            .english: "Paste automatically when chosen",
            .spanish: "Pegar automáticamente al elegir",
            .chinese: "选择后自动粘贴",
            .hindi: "चुनने पर अपने आप पेस्ट करें",
        ],
        "menu.launchAtLogin": [
            .english: "Open at login",
            .spanish: "Abrir al iniciar sesión",
            .chinese: "登录时打开",
            .hindi: "लॉगिन पर खोलें",
        ],
        "menu.pause": [
            .english: "Pause capturing",
            .spanish: "Pausar captura",
            .chinese: "暂停记录",
            .hindi: "कैप्चर रोकें",
        ],
        "menu.language": [
            .english: "Language",
            .spanish: "Idioma",
            .chinese: "语言",
            .hindi: "भाषा",
        ],
        "language.system": [
            .english: "System default",
            .spanish: "Idioma del sistema",
            .chinese: "跟随系统",
            .hindi: "सिस्टम डिफ़ॉल्ट",
        ],
        "menu.grantAccessibility": [
            .english: "⚠️ Grant Accessibility permission…",
            .spanish: "⚠️ Dar permiso de Accesibilidad…",
            .chinese: "⚠️ 授予辅助功能权限…",
            .hindi: "⚠️ एक्सेसिबिलिटी अनुमति दें…",
        ],
        "menu.clearHistory": [
            .english: "Clear history…",
            .spanish: "Borrar historial…",
            .chinese: "清除历史记录…",
            .hindi: "इतिहास साफ़ करें…",
        ],
        "menu.quit": [
            .english: "Quit ClipStack",
            .spanish: "Salir de ClipStack",
            .chinese: "退出 ClipStack",
            .hindi: "ClipStack बंद करें",
        ],

        // Alerts
        "alert.hotKeyFailed.title": [
            .english: "Couldn't register the shortcut %@",
            .spanish: "No se pudo registrar el atajo %@",
            .chinese: "无法注册快捷键 %@",
            .hindi: "शॉर्टकट %@ पंजीकृत नहीं हो सका",
        ],
        "alert.hotKeyFailed.body": [
            .english: "Another app may be using it. Choose a different shortcut from the ClipStack menu.",
            .spanish: "Puede que otra app lo esté usando. Elige otro atajo desde el menú de ClipStack.",
            .chinese: "可能有其他应用正在使用它。请从 ClipStack 菜单中选择其他快捷键。",
            .hindi: "हो सकता है कोई दूसरा ऐप इसका उपयोग कर रहा हो। ClipStack मेनू से कोई दूसरा शॉर्टकट चुनें।",
        ],
        "alert.clear.title": [
            .english: "Clear the entire history?",
            .spanish: "¿Borrar todo el historial?",
            .chinese: "清除全部历史记录？",
            .hindi: "पूरा इतिहास साफ़ करें?",
        ],
        "alert.clear.body": [
            .english: "All saved text, images and screenshots will be deleted.",
            .spanish: "Se eliminarán todos los textos, imágenes y capturas guardados.",
            .chinese: "所有已保存的文本、图片和截图都将被删除。",
            .hindi: "सभी सहेजे गए टेक्स्ट, छवियाँ और स्क्रीनशॉट हटा दिए जाएँगे।",
        ],
        "alert.clear.confirm": [
            .english: "Clear",
            .spanish: "Borrar",
            .chinese: "清除",
            .hindi: "साफ़ करें",
        ],
        "alert.cancel": [
            .english: "Cancel",
            .spanish: "Cancelar",
            .chinese: "取消",
            .hindi: "रद्द करें",
        ],
    ]
}
