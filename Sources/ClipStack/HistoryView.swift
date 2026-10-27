import SwiftUI

final class PanelState: ObservableObject {
    @Published var query = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    @Published var selection = 0
    /// Changes every time the panel opens so the search field regains focus.
    @Published var openCount = 0
}

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var state: PanelState
    let hotKeyTitle: String
    let onPick: (ClipItem) -> Void

    @FocusState private var searchFocused: Bool

    private var items: [ClipItem] { store.filtered(state.query) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L("search.placeholder"), text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if items.isEmpty {
                emptyState
            } else {
                list
            }

            Divider()
            footer
        }
        .onAppear { searchFocused = true }
        .onChange(of: state.openCount) { _ in searchFocused = true }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipRow(item: item, index: index, isSelected: index == state.selection, store: store)
                            .id(item.id)
                            .onTapGesture { onPick(item) }
                    }
                }
                .padding(6)
            }
            .onChange(of: state.selection) { newValue in
                guard items.indices.contains(newValue) else { return }
                proxy.scrollTo(items[newValue].id)
            }
            .onChange(of: state.openCount) { _ in
                if let first = items.first { proxy.scrollTo(first.id, anchor: .top) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 32)).foregroundStyle(.tertiary)
            Text(state.query.isEmpty ? L("empty.none") : L("empty.noResults"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text(L("footer.navigate"))
            Text(L("footer.paste"))
            Text(L("footer.quick"))
            Text(L("footer.delete"))
            Spacer()
            Text("esc · \(hotKeyTitle)")
        }
        .lineLimit(1)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let store: HistoryStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            icon
                .frame(width: 18)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                content
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor.opacity(0.28) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder private var icon: some View {
        switch item.kind {
        case .text: Image(systemName: "text.alignleft")
        case .image: Image(systemName: item.isScreenshot == true ? "camera.viewfinder" : "photo")
        case .files: Image(systemName: "doc")
        }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text:
            Text(preview(item.text ?? ""))
                .font(.system(size: 13))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            if let image = store.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 260, maxHeight: 90, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text(L("row.imageUnavailable")).foregroundStyle(.secondary)
            }
        case .files:
            let paths = item.paths ?? []
            Text(paths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", "))
                .font(.system(size: 13))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        switch item.kind {
        case .text:
            parts.append(L("row.characters", (item.text ?? "").count))
        case .image:
            if item.isScreenshot == true { parts.append(L("row.screenshot")) }
            if let size = store.imagePixelSize(for: item) {
                parts.append("\(Int(size.width))×\(Int(size.height))")
            }
        case .files:
            let count = item.paths?.count ?? 0
            parts.append(count == 1 ? L("row.oneFile") : L("row.files", count))
        }
        if let app = item.sourceApp { parts.append(app) }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        relative.locale = AppLanguage.current.locale
        parts.append(relative.localizedString(for: item.date, relativeTo: Date()))
        return parts.joined(separator: " · ")
    }

    private func preview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(400))
    }
}
