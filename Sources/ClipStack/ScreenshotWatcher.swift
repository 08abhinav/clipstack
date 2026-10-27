import Foundation

/// Detects screenshots saved to disk (⇧⌘3, ⇧⌘4, ⇧⌘5) through Spotlight.
/// Screenshots sent to the clipboard (⌃⇧⌘4) are already picked up by ClipboardMonitor.
final class ScreenshotWatcher: NSObject {
    private let query = NSMetadataQuery()
    private let onScreenshot: (URL) -> Void
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "gif"]

    init(onScreenshot: @escaping (URL) -> Void) {
        self.onScreenshot = onScreenshot
        super.init()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdate(_:)),
                                               name: .NSMetadataQueryDidUpdate, object: query)
    }

    func start() {
        if !query.isStarted { query.start() }
    }

    func stop() {
        query.stop()
    }

    @objc private func didUpdate(_ notification: Notification) {
        guard let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] else { return }
        for item in added {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let url = URL(fileURLWithPath: path)
            guard Self.imageExtensions.contains(url.pathExtension.lowercased()) else { continue }
            onScreenshot(url)
        }
    }
}
