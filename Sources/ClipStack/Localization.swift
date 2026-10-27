import Foundation

/// Languages the user can pick from the menu. English is the default.
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"

    /// Each language is shown in its own name so anyone can find theirs.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static var current: AppLanguage {
        get { UserDefaults.standard.string(forKey: "language").flatMap(AppLanguage.init) ?? .english }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "language") }
    }
}

/// Returns the translated string for `key`, formatting it with `args` when given.
func L(_ key: String, _ args: CVarArg...) -> String {
    let language = AppLanguage.current
    let format = Strings.table[key]?[language] ?? Strings.table[key]?[.english] ?? key
    return args.isEmpty ? format : String(format: format, locale: language.locale, arguments: args)
}

private enum Strings {
    static let table: [String: [AppLanguage: String]] = [
        // Panel
        "search.placeholder": [
            .english: "Search clipboard…",
            .spanish: "Buscar en el portapapeles…",
        ],
        "empty.none": [
            .english: "You haven't copied anything yet",
            .spanish: "Aún no has copiado nada",
        ],
        "empty.noResults": [
            .english: "No results",
            .spanish: "Sin resultados",
        ],
        "footer.navigate": [
            .english: "↑↓ navigate",
            .spanish: "↑↓ navegar",
        ],
        "footer.paste": [
            .english: "↩ paste",
            .spanish: "↩ pegar",
        ],
        "footer.quick": [
            .english: "⌘1–9 quick paste",
            .spanish: "⌘1–9 rápido",
        ],
        "footer.delete": [
            .english: "⌘⌫ delete",
            .spanish: "⌘⌫ borrar",
        ],

        // Rows
        "row.imageUnavailable": [
            .english: "Image unavailable",
            .spanish: "Imagen no disponible",
        ],
        "row.characters": [
            .english: "%d characters",
            .spanish: "%d caracteres",
        ],
        "row.screenshot": [
            .english: "Screenshot",
            .spanish: "Captura de pantalla",
        ],
        "row.oneFile": [
            .english: "1 file",
            .spanish: "1 archivo",
        ],
        "row.files": [
            .english: "%d files",
            .spanish: "%d archivos",
        ],

        // Menu
        "menu.show": [
            .english: "Show history (%@)",
            .spanish: "Mostrar historial (%@)",
        ],
        "menu.hotKey": [
            .english: "Keyboard shortcut",
            .spanish: "Atajo de teclado",
        ],
        "menu.historySize": [
            .english: "History size",
            .spanish: "Tamaño del historial",
        ],
        "menu.items": [
            .english: "%d items",
            .spanish: "%d elementos",
        ],
        "menu.captureScreenshots": [
            .english: "Save screenshots",
            .spanish: "Guardar capturas de pantalla",
        ],
        "menu.autoPaste": [
            .english: "Paste automatically when chosen",
            .spanish: "Pegar automáticamente al elegir",
        ],
        "menu.launchAtLogin": [
            .english: "Open at login",
            .spanish: "Abrir al iniciar sesión",
        ],
        "menu.pause": [
            .english: "Pause capturing",
            .spanish: "Pausar captura",
        ],
        "menu.language": [
            .english: "Language",
            .spanish: "Idioma",
        ],
        "menu.grantAccessibility": [
            .english: "⚠️ Grant Accessibility permission…",
            .spanish: "⚠️ Dar permiso de Accesibilidad…",
        ],
        "menu.clearHistory": [
            .english: "Clear history…",
            .spanish: "Borrar historial…",
        ],
        "menu.quit": [
            .english: "Quit ClipStack",
            .spanish: "Salir de ClipStack",
        ],

        // Alerts
        "alert.hotKeyFailed.title": [
            .english: "Couldn't register the shortcut %@",
            .spanish: "No se pudo registrar el atajo %@",
        ],
        "alert.hotKeyFailed.body": [
            .english: "Another app may be using it. Choose a different shortcut from the ClipStack menu.",
            .spanish: "Puede que otra app lo esté usando. Elige otro atajo desde el menú de ClipStack.",
        ],
        "alert.clear.title": [
            .english: "Clear the entire history?",
            .spanish: "¿Borrar todo el historial?",
        ],
        "alert.clear.body": [
            .english: "All saved text, images and screenshots will be deleted.",
            .spanish: "Se eliminarán todos los textos, imágenes y capturas guardados.",
        ],
        "alert.clear.confirm": [
            .english: "Clear",
            .spanish: "Borrar",
        ],
        "alert.cancel": [
            .english: "Cancel",
            .spanish: "Cancelar",
        ],
    ]
}
