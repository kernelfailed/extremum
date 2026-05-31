import SwiftUI
import UniformTypeIdentifiers

enum ExplorerFocusedField: Hashable {
    case address
    case search
}

extension FileEntry {
    var tint: Color {
        if isDirectory && !isPackage {
            return Color(red: 0.08, green: 0.43, blue: 0.88)
        }

        switch url.pathExtension.lowercased() {
        case "swift": return Color(red: 0.92, green: 0.31, blue: 0.12)
        case "json", "plist": return Color(red: 0.48, green: 0.33, blue: 0.74)
        case "csv", "xls", "xlsx", "numbers": return Color(red: 0.12, green: 0.55, blue: 0.36)
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return Color(red: 0.1, green: 0.56, blue: 0.68)
        case "zip", "rar", "7z", "tar", "gz": return Color(red: 0.52, green: 0.39, blue: 0.16)
        default: return .secondary
        }
    }
}

extension FinderTagColor {
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .gray: .gray
        }
    }
}

@MainActor
private func isCommandClick() -> Bool {
    NSApp.currentEvent?.modifierFlags.contains(.command) == true
}

@MainActor
private func isOptionPressed() -> Bool {
    NSApp.currentEvent?.modifierFlags.contains(.option) == true
}

private final class URLAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }

    var values: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private func loadFileURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
    let type = UTType.fileURL.identifier
    let group = DispatchGroup()
    let accumulator = URLAccumulator()

    for provider in providers where provider.hasItemConformingToTypeIdentifier(type) {
        group.enter()
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            defer { group.leave() }

            let url: URL?
            if let item = item as? URL {
                url = item
            } else if let item = item as? NSURL {
                url = item as URL
            } else if let data = item as? Data,
                      let string = String(data: data, encoding: .utf8) {
                url = URL(string: string)
            } else if let string = item as? String {
                url = URL(string: string)
            } else {
                url = nil
            }

            if let url, url.isFileURL {
                accumulator.append(url)
            }
        }
    }

    group.notify(queue: .main) {
        completion(accumulator.values)
    }
}

@MainActor
private func fileDragProvider(for entry: FileEntry, model: FileExplorerModel) -> NSItemProvider {
    if !model.selectedIDs.contains(entry.id) {
        model.select(entry)
    }

    let provider = NSItemProvider(contentsOf: entry.url) ?? NSItemProvider(object: entry.url as NSURL)
    provider.suggestedName = entry.name
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        let data = entry.url.absoluteString.data(using: .utf8)
        completion(data, nil)
        return nil
    }
    return provider
}

private struct FileEntryClickModifier: ViewModifier {
    @ObservedObject var model: FileExplorerModel
    let entry: FileEntry

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture(count: 1).onEnded {
                    model.select(entry, extending: isCommandClick())
                }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    model.open(entry)
                }
            )
    }
}

private extension View {
    func fileEntryClickActions(model: FileExplorerModel, entry: FileEntry) -> some View {
        modifier(FileEntryClickModifier(model: model, entry: entry))
    }
}

struct FileManagerRootView: View {
    @StateObject private var appState = ExplorerAppState()
    @FocusState private var focusedField: ExplorerFocusedField?
    @State private var debugWindowController: DebugWindowController?

    private var model: FileExplorerModel { appState.activeModel }

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(appState: appState)
            Divider()
            ExplorerToolbar(appState: appState, model: model, focusedField: $focusedField)
            Divider()

            HStack(spacing: 0) {
                SidebarView(model: model)
                    .frame(width: 220)
                Divider()
                if appState.dualPaneEnabled {
                    DualPaneView(appState: appState)
                } else {
                    ContentPane(model: model)
                }
            }

            Divider()
            StatusBar(appState: appState, model: model)
        }
        .frame(minWidth: 980, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .explorerCommand)) { notification in
            guard let command = notification.object as? ExplorerCommand else { return }
            handle(command)
        }
    }

    private func handle(_ command: ExplorerCommand) {
        switch command {
        case .newTab:
            appState.addTab()
        case .closeTab:
            appState.closeSelectedTab()
        case .selectTab(let index):
            appState.selectTab(at: index)
        case .nextTab:
            appState.selectNextTab()
        case .previousTab:
            appState.selectPreviousTab()
        case .toggleDualPane:
            appState.toggleDualPane()
        case .toggleDebug:
            showDebugWindow()
        case .focusAddress:
            focus(.address, selectText: true)
        case .focusSearch:
            focus(.search, selectText: true)
        case .clearFocus:
            if focusedField == .address {
                model.addressText = model.currentURL.path
            } else if focusedField == .search {
                model.searchText = ""
            }
            focusedField = nil
        case .reload:
            model.reload()
        case .back:
            model.goBack()
        case .forward:
            model.goForward()
        case .up:
            model.goUp()
        case .selectAll:
            model.selectAll()
        case .selectHoveredForContext:
            model.selectHoveredForContextMenu()
        case .openSelected:
            model.openSelected()
        case .quickLookSelected:
            let urls = model.selectedURLs()
            QuickLookPreviewController.shared.show(urls: urls)
            appState.log("Quick Look", "\(urls.count) items")
        case .toggleHidden:
            model.toggleHiddenFiles()
        case .setView(let viewMode):
            model.viewMode = viewMode
        case .create(let template):
            model.create(template)
        }
    }

    private func showDebugWindow() {
        if debugWindowController == nil {
            debugWindowController = DebugWindowController(appState: appState)
        }
        debugWindowController?.showWindow(nil)
        debugWindowController?.window?.makeKeyAndOrderFront(nil)
        appState.log("Debug", "Open debug window")
    }

    private func focus(_ field: ExplorerFocusedField, selectText: Bool) {
        focusedField = field
        guard selectText else { return }

        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }
}

struct TabBarView: View {
    @ObservedObject var appState: ExplorerAppState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(appState.tabs) { tab in
                Button {
                    appState.selectTab(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text(tab.title)
                            .lineLimit(1)
                        if appState.tabs.count > 1 && appState.selectedTabID == tab.id {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .onTapGesture {
                                    appState.closeSelectedTab()
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.selectedTabID == tab.id ? Color(nsColor: .textBackgroundColor) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                appState.addTab()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Новая вкладка")

            Spacer()
        }
        .padding(.top, 32)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .background(.regularMaterial)
    }
}

struct ExplorerToolbar: View {
    @ObservedObject var appState: ExplorerAppState
    @ObservedObject var model: FileExplorerModel
    var focusedField: FocusState<ExplorerFocusedField?>.Binding

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: model.goBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(ExplorerIconButtonStyle())
                .disabled(!model.canGoBack)
                .help("Назад")

                Button(action: model.goForward) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(ExplorerIconButtonStyle())
                .disabled(!model.canGoForward)
                .help("Вперед")

                Button(action: model.goUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(ExplorerIconButtonStyle())
                .disabled(!model.canGoUp)
                .help("Вверх")

                AddressField(model: model, focusedField: focusedField)

                SearchField(text: $model.searchText, focusedField: focusedField)
                    .frame(width: 230)
            }

            HStack(spacing: 10) {
                Menu {
                    CreateItemsMenu(model: model)
                } label: {
                    Label("Создать", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Toggle(isOn: $model.showHiddenFiles) {
                    Image(systemName: model.showHiddenFiles ? "eye.fill" : "eye.slash.fill")
                }
                .toggleStyle(.button)
                .help("Скрытые файлы")

                Toggle(isOn: $appState.dualPaneEnabled) {
                    Image(systemName: "rectangle.split.2x1")
                }
                .toggleStyle(.button)
                .help("Две панели")

                Button {
                    NotificationCenter.default.post(name: .explorerCommand, object: ExplorerCommand.toggleDebug)
                } label: {
                    Image(systemName: "terminal")
                }
                .buttonStyle(ExplorerIconButtonStyle())
                .help("Debug log")

                Picker("Вид", selection: $model.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 330)

                Picker("Сортировка", selection: $model.sortKey) {
                    ForEach(SortKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                .frame(width: 150)

                Spacer()

                Text(model.currentURL.lastPathComponent.isEmpty ? "/" : model.currentURL.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }
}

struct AddressField: View {
    @ObservedObject var model: FileExplorerModel
    var focusedField: FocusState<ExplorerFocusedField?>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color(red: 0.08, green: 0.43, blue: 0.88))
            TextField("Путь", text: $model.addressText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(1)
                .focused(focusedField, equals: .address)
                .onSubmit(model.navigateFromAddress)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

struct SearchField: View {
    @Binding var text: String
    var focusedField: FocusState<ExplorerFocusedField?>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск", text: $text)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .focused(focusedField, equals: .search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

struct SidebarView: View {
    @ObservedObject var model: FileExplorerModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
            ForEach(model.sidebarSections) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)

                    ForEach(section.locations) { location in
                        SidebarLocationRow(
                            model: model,
                            location: location,
                            isSelected: model.currentURL.standardizedFileURL.path == location.url.standardizedFileURL.path
                        )
                    }
                }
            }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct SidebarLocationRow: View {
    @ObservedObject var model: FileExplorerModel
    let location: SidebarLocation
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: location.symbol)
                .frame(width: 20)
            Text(location.title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.navigate(to: location.url)
        }
        .contextMenu {
            Button {
                model.navigate(to: location.url)
            } label: {
                Label("Открыть", systemImage: "arrow.right.circle")
            }
        }
    }
}

struct DualPaneView: View {
    @ObservedObject var appState: ExplorerAppState

    var body: some View {
        HStack(spacing: 0) {
            PaneContainer(
                title: "Левая панель",
                pane: .left,
                isActive: appState.activePane == .left,
                model: appState.model(for: .left)
            ) {
                appState.setActivePane(.left)
            }

            Divider()

            PaneContainer(
                title: "Правая панель",
                pane: .right,
                isActive: appState.activePane == .right,
                model: appState.model(for: .right)
            ) {
                appState.setActivePane(.right)
            }
        }
    }
}

struct PaneContainer: View {
    let title: String
    let pane: PaneSide
    let isActive: Bool
    @ObservedObject var model: FileExplorerModel
    let activate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isActive ? Color.accentColor : Color(nsColor: .separatorColor))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(model.currentURL.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(isActive ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))

            ContentPane(model: model)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: activate)
    }
}

struct ContentPane: View {
    @ObservedObject var model: FileExplorerModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.clearSelection()
                }

            if model.filteredEntries.isEmpty {
                EmptyDirectoryView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch model.viewMode {
                case .icons:
                    FixedIconGrid(model: model, entries: model.filteredEntries, variant: .icons)
                case .tiles:
                    FixedTileGrid(model: model, entries: model.filteredEntries)
                case .list:
                    FileListView(model: model, entries: model.filteredEntries)
                case .columns:
                    ColumnBrowserView(model: model, entries: model.filteredEntries)
                }
            }
        }
        .contextMenu {
            CreateSubmenu(model: model)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            loadFileURLs(from: providers) { urls in
                model.moveDroppedItems(urls, copy: isOptionPressed())
            }
            return true
        }
    }
}

struct EmptyDirectoryView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Папка пуста")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct CreateItemsMenu: View {
    @ObservedObject var model: FileExplorerModel

    var body: some View {
        ForEach(CreationTemplate.allCases) { template in
            Button {
                model.create(template)
            } label: {
                Label(template.title, systemImage: template.symbol)
            }
        }
    }
}

struct CreateSubmenu: View {
    @ObservedObject var model: FileExplorerModel

    var body: some View {
        Menu {
            CreateItemsMenu(model: model)
        } label: {
            Label("Создать", systemImage: "plus")
        }
    }
}

enum IconGridVariant {
    case icons

    var itemWidth: CGFloat { 112 }
    var itemHeight: CGFloat { 118 }
    var spacing: CGFloat { 14 }
}

struct FixedIconGrid: View {
    @ObservedObject var model: FileExplorerModel
    let entries: [FileEntry]
    let variant: IconGridVariant
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var isMarqueeActive = false
    @State private var itemFrames: [String: CGRect] = [:]
    private let coordinateSpaceName = "Extremum.FixedIconGrid"

    var body: some View {
        GeometryReader { proxy in
            let columns = columnsFor(width: proxy.size.width)

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: variant.spacing) {
                    ForEach(entries) { entry in
                        FileIconCell(model: model, entry: entry)
                            .frame(width: variant.itemWidth, height: variant.itemHeight)
                            .background(FileItemFrameReporter(id: entry.id, coordinateSpace: coordinateSpaceName))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .coordinateSpace(name: coordinateSpaceName)
            .onPreferenceChange(FileItemFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.clearSelection()
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    if model.hoveredEntryID == nil {
                        model.clearSelection()
                    }
                }
            )
            .overlay {
                SelectionRectangleView(start: dragStart, current: dragCurrent)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if dragStart == nil {
                            guard id(at: value.startLocation) == nil else { return }
                            isMarqueeActive = true
                            dragStart = value.startLocation
                        }
                        guard isMarqueeActive, let start = dragStart else { return }
                        dragCurrent = value.location
                        let rect = normalizedRect(from: start, to: value.location)
                        model.previewSelection(ids: ids(in: rect))
                    }
                    .onEnded { value in
                        guard isMarqueeActive, let start = dragStart else {
                            isMarqueeActive = false
                            return
                        }
                        let rect = normalizedRect(from: start, to: value.location)
                        model.select(ids: ids(in: rect))
                        isMarqueeActive = false
                        dragStart = nil
                        dragCurrent = nil
                    }
            )
        }
    }

    private func ids(in rect: CGRect) -> Set<String> {
        Set(itemFrames.compactMap { id, frame in
            rect.intersects(frame) ? id : nil
        })
    }

    private func id(at point: CGPoint) -> String? {
        itemFrames.first { _, frame in frame.contains(point) }?.key
    }

    private func columnsFor(width: CGFloat) -> [GridItem] {
        let available = max(width - 32, variant.itemWidth)
        let count = max(Int((available + variant.spacing) / (variant.itemWidth + variant.spacing)), 1)
        return Array(
            repeating: GridItem(.fixed(variant.itemWidth), spacing: variant.spacing, alignment: .top),
            count: count
        )
    }
}

struct FileIconCell: View {
    @ObservedObject var model: FileExplorerModel
    let entry: FileEntry

    private var isSelected: Bool { model.selectedIDs.contains(entry.id) }

    var body: some View {
        VStack(spacing: 8) {
            FileThumbnailView(entry: entry, size: 62)

            Text(entry.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 96, height: 34, alignment: .top)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(selectionBackground)
        .opacity(entry.isHidden ? 0.48 : 1)
        .contentShape(Rectangle())
        .fileEntryClickActions(model: model, entry: entry)
        .onHover { hovering in
            model.setHovered(entry, hovering: hovering)
        }
        .onDrag {
            fileDragProvider(for: entry, model: model)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard entry.isDirectory && !entry.isPackage else { return false }
            loadFileURLs(from: providers) { urls in
                model.moveDroppedItems(urls, to: entry.url, copy: isOptionPressed())
            }
            return true
        }
        .contextMenu {
            EntryContextMenu(model: model, entry: entry)
        }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
            )
    }
}

struct FixedTileGrid: View {
    @ObservedObject var model: FileExplorerModel
    let entries: [FileEntry]

    private let itemWidth: CGFloat = 242
    private let itemHeight: CGFloat = 82
    private let spacing: CGFloat = 12
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var isMarqueeActive = false
    @State private var itemFrames: [String: CGRect] = [:]
    private let coordinateSpaceName = "Extremum.FixedTileGrid"

    var body: some View {
        GeometryReader { proxy in
            let columns = columnsFor(width: proxy.size.width)

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    ForEach(entries) { entry in
                        FileTileCell(model: model, entry: entry)
                            .frame(width: itemWidth, height: itemHeight)
                            .background(FileItemFrameReporter(id: entry.id, coordinateSpace: coordinateSpaceName))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .coordinateSpace(name: coordinateSpaceName)
            .onPreferenceChange(FileItemFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.clearSelection()
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    if model.hoveredEntryID == nil {
                        model.clearSelection()
                    }
                }
            )
            .overlay {
                SelectionRectangleView(start: dragStart, current: dragCurrent)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if dragStart == nil {
                            guard id(at: value.startLocation) == nil else { return }
                            isMarqueeActive = true
                            dragStart = value.startLocation
                        }
                        guard isMarqueeActive, let start = dragStart else { return }
                        dragCurrent = value.location
                        let rect = normalizedRect(from: start, to: value.location)
                        model.previewSelection(ids: ids(in: rect))
                    }
                    .onEnded { value in
                        guard isMarqueeActive, let start = dragStart else {
                            isMarqueeActive = false
                            return
                        }
                        let rect = normalizedRect(from: start, to: value.location)
                        model.select(ids: ids(in: rect))
                        isMarqueeActive = false
                        dragStart = nil
                        dragCurrent = nil
                    }
            )
        }
    }

    private func ids(in rect: CGRect) -> Set<String> {
        Set(itemFrames.compactMap { id, frame in
            rect.intersects(frame) ? id : nil
        })
    }

    private func id(at point: CGPoint) -> String? {
        itemFrames.first { _, frame in frame.contains(point) }?.key
    }

    private func columnsFor(width: CGFloat) -> [GridItem] {
        let available = max(width - 32, itemWidth)
        let count = max(Int((available + spacing) / (itemWidth + spacing)), 1)
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: count)
    }
}

struct FileTileCell: View {
    @ObservedObject var model: FileExplorerModel
    let entry: FileEntry

    private var isSelected: Bool { model.selectedIDs.contains(entry.id) }

    var body: some View {
        HStack(spacing: 12) {
            FileThumbnailView(entry: entry, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(entry.kind)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.displaySize)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .opacity(entry.isHidden ? 0.48 : 1)
        .contentShape(Rectangle())
        .fileEntryClickActions(model: model, entry: entry)
        .onHover { hovering in
            model.setHovered(entry, hovering: hovering)
        }
        .onDrag {
            fileDragProvider(for: entry, model: model)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard entry.isDirectory && !entry.isPackage else { return false }
            loadFileURLs(from: providers) { urls in
                model.moveDroppedItems(urls, to: entry.url, copy: isOptionPressed())
            }
            return true
        }
        .contextMenu {
            EntryContextMenu(model: model, entry: entry)
        }
    }
}

struct FileListView: View {
    @ObservedObject var model: FileExplorerModel
    let entries: [FileEntry]
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var isMarqueeActive = false
    @State private var itemFrames: [String: CGRect] = [:]
    private let coordinateSpaceName = "Extremum.FileListView"

    var body: some View {
        GeometryReader { proxy in
            let nameWidth = max(proxy.size.width - 520, 260)

            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ListHeader(nameWidth: nameWidth)
                    ForEach(entries) { entry in
                        FileListRow(model: model, entry: entry, nameWidth: nameWidth)
                            .background(FileItemFrameReporter(id: entry.id, coordinateSpace: coordinateSpaceName))
                    }
                }
                .padding(.vertical, 8)
                .frame(minWidth: proxy.size.width, alignment: .topLeading)
            }
            .coordinateSpace(name: coordinateSpaceName)
            .onPreferenceChange(FileItemFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.clearSelection()
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    if model.hoveredEntryID == nil {
                        model.clearSelection()
                    }
                }
            )
            .overlay {
                SelectionRectangleView(start: dragStart, current: dragCurrent)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if dragStart == nil {
                            guard id(at: value.startLocation) == nil else { return }
                            isMarqueeActive = true
                            dragStart = value.startLocation
                        }
                        guard isMarqueeActive, let start = dragStart else { return }
                        dragCurrent = value.location
                        let rect = normalizedRect(from: start, to: value.location)
                        model.previewSelection(ids: ids(in: rect))
                    }
                    .onEnded { value in
                        guard isMarqueeActive, let start = dragStart else {
                            isMarqueeActive = false
                            return
                        }
                        let rect = normalizedRect(from: start, to: value.location)
                        model.select(ids: ids(in: rect))
                        isMarqueeActive = false
                        dragStart = nil
                        dragCurrent = nil
                    }
            )
        }
    }

    private func ids(in rect: CGRect) -> Set<String> {
        Set(itemFrames.compactMap { id, frame in
            rect.intersects(frame) ? id : nil
        })
    }

    private func id(at point: CGPoint) -> String? {
        itemFrames.first { _, frame in frame.contains(point) }?.key
    }
}

struct SelectionRectangleView: View {
    let start: CGPoint?
    let current: CGPoint?

    var body: some View {
        if let start, let current {
            let rect = normalizedRect(from: start, to: current)
            Rectangle()
                .fill(Color.accentColor.opacity(0.12))
                .overlay(Rectangle().stroke(Color.accentColor.opacity(0.65), lineWidth: 1))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
    }
}

private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
    CGRect(
        x: min(start.x, end.x),
        y: min(start.y, end.y),
        width: abs(start.x - end.x),
        height: abs(start.y - end.y)
    )
}

private struct FileItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct FileItemFrameReporter: View {
    let id: String
    let coordinateSpace: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: FileItemFramePreferenceKey.self,
                value: [id: proxy.frame(in: .named(coordinateSpace))]
            )
        }
    }
}

struct ListHeader: View {
    let nameWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HeaderText("Имя").frame(width: nameWidth, alignment: .leading)
            HeaderText("Изменен").frame(width: 180, alignment: .leading)
            HeaderText("Тип").frame(width: 210, alignment: .leading)
            HeaderText("Размер").frame(width: 120, alignment: .trailing)
        }
        .frame(height: 30)
        .padding(.horizontal, 14)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

struct HeaderText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

struct FileListRow: View {
    @ObservedObject var model: FileExplorerModel
    let entry: FileEntry
    let nameWidth: CGFloat

    private var isSelected: Bool { model.selectedIDs.contains(entry.id) }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                FileThumbnailView(entry: entry, size: 20)
                Text(entry.name)
                    .lineLimit(1)
            }
            .frame(width: nameWidth, alignment: .leading)

            Text(entry.modifiedText)
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)
                .foregroundStyle(.secondary)

            Text(entry.kind)
                .lineLimit(1)
                .frame(width: 210, alignment: .leading)
                .foregroundStyle(.secondary)

            Text(entry.displaySize)
                .lineLimit(1)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .frame(height: 34)
        .padding(.horizontal, 14)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        .opacity(entry.isHidden ? 0.48 : 1)
        .contentShape(Rectangle())
        .fileEntryClickActions(model: model, entry: entry)
        .onHover { hovering in
            model.setHovered(entry, hovering: hovering)
        }
        .onDrag {
            fileDragProvider(for: entry, model: model)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard entry.isDirectory && !entry.isPackage else { return false }
            loadFileURLs(from: providers) { urls in
                model.moveDroppedItems(urls, to: entry.url, copy: isOptionPressed())
            }
            return true
        }
        .contextMenu {
            EntryContextMenu(model: model, entry: entry)
        }
    }
}

struct ColumnBrowserView: View {
    @ObservedObject var model: FileExplorerModel
    let entries: [FileEntry]

    var body: some View {
        HStack(spacing: 0) {
            ColumnList(
                title: model.parentURL?.lastPathComponent.isEmpty == false ? model.parentURL!.lastPathComponent : "/",
                entries: model.entriesForParentColumn(),
                selectedID: model.currentURL.path
            ) { entry in
                if entry.isDirectory {
                    model.navigate(to: entry.url)
                }
            }
            .frame(width: 240)

            Divider()

            ColumnList(
                title: model.currentURL.lastPathComponent.isEmpty ? "/" : model.currentURL.lastPathComponent,
                entries: entries,
                selectedID: model.selectedID
            ) { entry in
                model.select(entry)
                if entry.isDirectory && !entry.isPackage {
                    model.navigate(to: entry.url)
                }
            }
            .frame(width: 280)

            Divider()

            PreviewPane(entry: model.selectedEntry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ColumnList: View {
    let title: String
    let entries: [FileEntry]
    let selectedID: String?
    let action: (FileEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(nsColor: .controlBackgroundColor))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            FileThumbnailView(entry: entry, size: 20)
                            Text(entry.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if entry.isDirectory && !entry.isPackage {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 32)
                        .padding(.horizontal, 10)
                        .background(selectedID == entry.id ? Color.accentColor.opacity(0.16) : Color.clear)
                        .opacity(entry.isHidden ? 0.48 : 1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            action(entry)
                        }
                    }
                }
            }
        }
    }
}

struct PreviewPane: View {
    let entry: FileEntry?

    var body: some View {
        VStack(spacing: 14) {
            if let entry {
                FileThumbnailView(entry: entry, size: 96)

                Text(entry.name)
                    .font(.system(size: 18, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                VStack(spacing: 8) {
                    PreviewRow(label: "Тип", value: entry.kind)
                    PreviewRow(label: "Размер", value: entry.displaySize)
                    PreviewRow(label: "Изменен", value: entry.modifiedText)
                    PreviewRow(label: "Путь", value: entry.url.path)
                }
                .padding(.top, 8)
            } else {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Нет выбора")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct PreviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
    }
}

struct EntryContextMenu: View {
    @ObservedObject var model: FileExplorerModel
    let entry: FileEntry

    var body: some View {
        Group {
            if ContextMenuPreferences.isEnabled(.open) {
                Button {
                    model.open(entry)
                } label: {
                    Label("Открыть", systemImage: "arrow.right.circle")
                }
            }

            if ContextMenuPreferences.isEnabled(.openWith) {
                OpenWithMenu(model: model, entry: entry)
            }

            if ContextMenuPreferences.isEnabled(.showPackageContents), entry.isPackage {
                Button {
                    model.showPackageContents(entry)
                } label: {
                    Label("Показать содержимое пакета", systemImage: "shippingbox")
                }
            }

            if ContextMenuPreferences.isEnabled(.moveToTrash) {
                Divider()

                Button(role: .destructive) {
                    model.moveSelectedToTrash()
                } label: {
                    Label("Переместить в Корзину", systemImage: "trash")
                }
            }

            Divider()

            if ContextMenuPreferences.isEnabled(.getInfo) {
                Button {
                    model.showInfo(for: entry)
                } label: {
                    Label("Свойства", systemImage: "info.circle")
                }
            }

            if ContextMenuPreferences.isEnabled(.rename) {
                Button {
                    model.rename(entry)
                } label: {
                    Label("Переименовать", systemImage: "pencil")
                }
            }

            if ContextMenuPreferences.isEnabled(.compress) {
                Button {
                    model.compressSelected()
                } label: {
                    Label("Сжать", systemImage: "archivebox")
                }
            }

            if ContextMenuPreferences.isEnabled(.decompress), model.canDecompressSelected() {
                Button {
                    model.decompressSelected()
                } label: {
                    Label("Разархивировать", systemImage: "archivebox.fill")
                }
            }

            if ContextMenuPreferences.isEnabled(.duplicate) {
                Button {
                    model.duplicateSelected()
                } label: {
                    Label("Дублировать", systemImage: "plus.square.on.square")
                }
            }

            if ContextMenuPreferences.isEnabled(.makeAlias) {
                Button {
                    model.makeAliasForSelected()
                } label: {
                    Label("Создать псевдоним", systemImage: "arrowshape.turn.up.right")
                }
            }

            if ContextMenuPreferences.isEnabled(.quickLook) {
                Button {
                    QuickLookPreviewController.shared.show(urls: model.selectedURLs())
                } label: {
                    Label("Быстрый просмотр", systemImage: "eye")
                }
            }

            Divider()

            if ContextMenuPreferences.isEnabled(.copy) {
                Button {
                    model.copySelectedPathsToPasteboard()
                } label: {
                    Label("Скопировать", systemImage: "doc.on.doc")
                }
            }

            if ContextMenuPreferences.isEnabled(.share) {
                Button {
                    model.shareSelected()
                } label: {
                    Label("Поделиться...", systemImage: "square.and.arrow.up")
                }
            }

            if ContextMenuPreferences.isEnabled(.colorTags) || ContextMenuPreferences.isEnabled(.tags) {
                Divider()
            }

            if ContextMenuPreferences.isEnabled(.colorTags) {
                TagSwatchesMenu(model: model)
            }

            if ContextMenuPreferences.isEnabled(.tags) {
                Button {
                    model.editTags()
                } label: {
                    Label("Теги...", systemImage: "tag")
                }
            }

            if ContextMenuPreferences.isEnabled(.quickActions) {
                Divider()
                Menu {
                    Button {
                        model.revealSelectedInFinder()
                    } label: {
                        Label("Показать быстрые действия в Finder", systemImage: "sparkles")
                    }
                } label: {
                    Label("Быстрые действия", systemImage: "wand.and.stars")
                }
            }

            if ContextMenuPreferences.isEnabled(.terminal) {
                Divider()
                Button {
                    model.openTerminal(at: entry)
                } label: {
                    Label("Новый терминал по адресу папки", systemImage: "terminal")
                }
            }

            if ContextMenuPreferences.isEnabled(.revealInFinder) {
                Divider()
                Button {
                    model.revealInFinder(entry)
                } label: {
                    Label("Показать в Finder", systemImage: "finder")
                }

                Button {
                    model.revealSelectedInFinder()
                } label: {
                    Label("Показать выбранные в Finder", systemImage: "rectangle.stack")
                }
            }

            if ContextMenuPreferences.isEnabled(.git), model.gitRoot != nil {
                Divider()

                Button {
                    model.openGitRoot()
                } label: {
                    Label("Открыть Git root", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }

                Button {
                    model.copyGitStatusForSelected()
                } label: {
                    Label("Скопировать Git status", systemImage: "terminal")
                }
            }

            if ContextMenuPreferences.isEnabled(.create) {
                Divider()
                CreateSubmenu(model: model)
            }
        }
    }
}

struct OpenWithMenu: View {
    @ObservedObject var model: FileExplorerModel
    let entry: FileEntry

    var body: some View {
        let applications = model.openWithApplications(for: entry)
        Menu {
            if applications.isEmpty {
                Text("Недоступно для разных типов")
            } else {
                ForEach(applications) { application in
                    Button {
                        model.openSelected(withApplicationAt: application.url)
                    } label: {
                        Label(application.name, systemImage: "app")
                    }
                }
            }

            Divider()

            Button {
                model.chooseApplicationForSelected()
            } label: {
                Label("Другое...", systemImage: "ellipsis.circle")
            }
        } label: {
            Label("Открыть с помощью", systemImage: "square.grid.2x2")
        }
    }
}

struct TagSwatchesMenu: View {
    @ObservedObject var model: FileExplorerModel

    var body: some View {
        Menu {
            ForEach(FinderTagColor.allCases) { tag in
                Button {
                    model.applyTag(tag)
                } label: {
                    Label(tag.title, systemImage: "tag.fill")
                }
            }
        } label: {
            Label("Цветные теги", systemImage: "tag")
        }
    }
}

struct StatusBar: View {
    @ObservedObject var appState: ExplorerAppState
    @ObservedObject var model: FileExplorerModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color(red: 0.08, green: 0.43, blue: 0.88))

            Text(model.statusMessage)
                .lineLimit(1)

            if !model.selectedIDs.isEmpty {
                Divider()
                    .frame(height: 14)
                Text("\(model.selectedIDs.count) выбрано")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 14)

            Text(appState.activePane.title)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            if let branch = model.gitBranch, let root = model.gitRoot {
                Divider()
                    .frame(height: 14)
                Label(branch.isEmpty ? "detached" : branch, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .help(root.path)
            }

            Spacer()

            Text(model.currentURL.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(.regularMaterial)
    }
}

struct ExplorerIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 30, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.18) : Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}
