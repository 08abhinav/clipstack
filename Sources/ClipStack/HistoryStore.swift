import AppKit
import CryptoKit
import ImageIO

struct ClipItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case text, image, files
    }

    let id: UUID
    var kind: Kind
    var text: String?
    var imageFile: String?
    var imageHash: String?
    var paths: [String]?
    var date: Date
    var sourceApp: String?
    var isScreenshot: Bool?

    /// Text used when searching the history.
    var searchableText: String {
        switch kind {
        case .text: return text ?? ""
        case .image: return (isScreenshot == true ? Self.screenshotKeywords : Self.imageKeywords) + (sourceApp ?? "")
        case .files: return (paths ?? []).joined(separator: " ")
        }
    }

    // Keywords in every supported language so images can be found by search.
    private static let imageKeywords = "image imagen "
    private static let screenshotKeywords = "screenshot captura pantalla "
}

/// Persists the history in ~/Library/Application Support/ClipStack.
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    var maxItems: Int {
        get { UserDefaults.standard.object(forKey: "maxItems") as? Int ?? 200 }
        set { UserDefaults.standard.set(newValue, forKey: "maxItems"); trim(); save() }
    }

    private let baseURL: URL
    private let imagesURL: URL
    private let historyURL: URL
    private let thumbnails = NSCache<NSString, NSImage>()
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = support.appendingPathComponent("ClipStack", isDirectory: true)
        imagesURL = baseURL.appendingPathComponent("images", isDirectory: true)
        historyURL = baseURL.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Adding

    func addText(_ text: String, sourceApp: String?) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let index = items.firstIndex(where: { $0.kind == .text && $0.text == text }) {
            moveToTop(index)
            return
        }
        insert(ClipItem(id: UUID(), kind: .text, text: text, date: Date(), sourceApp: sourceApp))
    }

    func addImage(data: Data, sourceApp: String?, isScreenshot: Bool = false) {
        guard let png = Self.pngData(from: data) else { return }
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        if let index = items.firstIndex(where: { $0.kind == .image && $0.imageHash == hash }) {
            moveToTop(index)
            return
        }
        let id = UUID()
        let fileName = "\(id.uuidString).png"
        do {
            try png.write(to: imagesURL.appendingPathComponent(fileName))
        } catch {
            NSLog("ClipStack: could not save image: \(error)")
            return
        }
        insert(ClipItem(id: id, kind: .image, imageFile: fileName, imageHash: hash,
                        date: Date(), sourceApp: sourceApp, isScreenshot: isScreenshot))
    }

    func addFiles(_ urls: [URL], sourceApp: String?) {
        let paths = urls.map(\.path)
        guard !paths.isEmpty else { return }
        if let index = items.firstIndex(where: { $0.kind == .files && $0.paths == paths }) {
            moveToTop(index)
            return
        }
        insert(ClipItem(id: UUID(), kind: .files, paths: paths, date: Date(), sourceApp: sourceApp))
    }

    // MARK: - Editing

    func moveToTop(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) { moveToTop(index) }
    }

    func remove(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        deleteFiles(of: items[index])
        items.remove(at: index)
        save()
    }

    func clear() {
        items.forEach(deleteFiles)
        items.removeAll()
        save()
    }

    func filtered(_ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { $0.searchableText.localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Pasting

    /// Writes the item to the system pasteboard.
    func write(_ item: ClipItem, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        switch item.kind {
        case .text:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .image:
            guard let url = imageURL(for: item), let png = try? Data(contentsOf: url) else { return }
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(png, forType: .png)
            if let tiff = NSImage(data: png)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .files:
            let urls = (item.paths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(urls)
        }
    }

    // MARK: - Images

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imagesURL.appendingPathComponent($0) }
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        guard let file = item.imageFile, let url = imageURL(for: item) else { return nil }
        if let cached = thumbnails.object(forKey: file as NSString) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 400,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        thumbnails.setObject(image, forKey: file as NSString)
        return image
    }

    func imagePixelSize(for item: ClipItem) -> CGSize? {
        guard let url = imageURL(for: item),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: w, height: h)
    }

    private static func pngData(from data: Data) -> Data? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return data }
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Private

    private func insert(_ item: ClipItem) {
        items.insert(item, at: 0)
        trim()
        save()
    }

    private func moveToTop(_ index: Int) {
        var item = items.remove(at: index)
        item.date = Date()
        items.insert(item, at: 0)
        save()
    }

    private func trim() {
        while items.count > maxItems {
            deleteFiles(of: items.removeLast())
        }
    }

    private func deleteFiles(of item: ClipItem) {
        guard let file = item.imageFile, let url = imageURL(for: item) else { return }
        thumbnails.removeObject(forKey: file as NSString)
        try? FileManager.default.removeItem(at: url)
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        saveWorkItem?.cancel()
        let snapshot = items
        let url = historyURL
        let work = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
