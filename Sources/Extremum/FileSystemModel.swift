import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable, Identifiable {
    case icons
    case tiles
    case list
    case columns

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icons: "Значки"
        case .tiles: "Плитка"
        case .list: "Список"
        case .columns: "Колонки"
        }
    }

    var symbol: String {
        switch self {
        case .icons: "square.grid.3x3.fill"
        case .tiles: "rectangle.grid.2x2.fill"
        case .list: "list.bullet"
        case .columns: "rectangle.split.3x1.fill"
        }
    }
}

enum SortKey: String, CaseIterable, Identifiable {
    case name
    case modified
    case kind
    case size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Имя"
        case .modified: "Изменен"
        case .kind: "Тип"
        case .size: "Размер"
        }
    }
}

enum CreationTemplate: String, CaseIterable, Identifiable {
    case folder
    case text
    case markdown
    case json
    case csv
    case html
    case swift
    case plist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .folder: "Папку"
        case .text: "Текстовый файл"
        case .markdown: "Markdown"
        case .json: "JSON"
        case .csv: "CSV"
        case .html: "HTML"
        case .swift: "Swift"
        case .plist: "Property List"
        }
    }

    var baseName: String {
        switch self {
        case .folder: "Новая папка"
        case .text: "Новый текстовый файл"
        case .markdown: "Новый документ"
        case .json: "Новый JSON"
        case .csv: "Новая таблица"
        case .html: "Новая страница"
        case .swift: "Новый Swift файл"
        case .plist: "Новый plist"
        }
    }

    var fileExtension: String? {
        switch self {
        case .folder: nil
        case .text: "txt"
        case .markdown: "md"
        case .json: "json"
        case .csv: "csv"
        case .html: "html"
        case .swift: "swift"
        case .plist: "plist"
        }
    }

    var symbol: String {
        switch self {
        case .folder: "folder.badge.plus"
        case .text: "doc.text"
        case .markdown: "doc.richtext"
        case .json: "curlybraces"
        case .csv: "tablecells"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .swift: "swift"
        case .plist: "list.bullet.rectangle"
        }
    }

    var contents: String {
        switch self {
        case .folder:
            ""
        case .text:
            ""
        case .markdown:
            "# Новый документ\n"
        case .json:
            "{\n  \"name\": \"\"\n}\n"
        case .csv:
            "name,value\n"
        case .html:
            """
            <!doctype html>
            <html lang="ru">
            <head>
              <meta charset="utf-8">
              <title>Новая страница</title>
            </head>
            <body>
            </body>
            </html>
            """
        case .swift:
            "import Foundation\n\n"
        case .plist:
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            </dict>
            </plist>
            """
        }
    }
}

struct SidebarSection: Identifiable {
    let id = UUID()
    let title: String
    let locations: [SidebarLocation]
}

struct SidebarLocation: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let symbol: String
}

enum GitFileStatus: String {
    case modified
    case added
    case deleted
    case renamed
    case untracked
    case conflict

    var title: String {
        switch self {
        case .modified: "modified"
        case .added: "added"
        case .deleted: "deleted"
        case .renamed: "renamed"
        case .untracked: "untracked"
        case .conflict: "conflict"
        }
    }

    var symbol: String {
        switch self {
        case .modified: "m.circle.fill"
        case .added: "plus.circle.fill"
        case .deleted: "minus.circle.fill"
        case .renamed: "arrow.triangle.2.circlepath.circle.fill"
        case .untracked: "questionmark.circle.fill"
        case .conflict: "exclamationmark.triangle.fill"
        }
    }
}

struct FileEntry: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let size: Int64?
    let modified: Date?
    let kind: String
    let symbol: String
    let isHidden: Bool
    let gitStatus: GitFileStatus?

    var displaySize: String {
        guard !isDirectory, let size else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: size)
    }

    var modifiedText: String {
        guard let modified else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modified)
    }
}

struct ApplicationOption: Identifiable, Hashable {
    let url: URL
    let name: String

    var id: String { url.path }
}

enum ExplorerError: LocalizedError {
    case cannotCreate(URL)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreate(let url):
            return "Не удалось создать \(url.lastPathComponent)."
        case .operationFailed(let message):
            return message
        }
    }
}

enum SearchMode {
    case contains(String)
    case exact(String)
    case glob(String)

    init?(rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        if query.count >= 2, query.hasPrefix("\""), query.hasSuffix("\"") {
            let exact = String(query.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !exact.isEmpty else { return nil }
            self = .exact(exact)
        } else if query.contains("*") || query.contains("?") {
            self = .glob(query)
        } else {
            self = .contains(query)
        }
    }

    var description: String {
        switch self {
        case .contains(let value): return "contains \(value)"
        case .exact(let value): return "exact \(value)"
        case .glob(let value): return "glob \(value)"
        }
    }

    func matches(_ name: String) -> Bool {
        switch self {
        case .contains(let value):
            return name.localizedCaseInsensitiveContains(value)
        case .exact(let value):
            return name.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        case .glob(let value):
            return NSPredicate(format: "SELF LIKE[c] %@", value).evaluate(with: name)
        }
    }
}

@MainActor
final class FileExplorerModel: ObservableObject {
    private static let recursiveSearchLimit = 1_000

    @Published var currentURL: URL
    @Published var addressText: String
    @Published var entries: [FileEntry] = []
    @Published var selectedID: String?
    @Published var selectedIDs: Set<String> = []
    @Published var searchText = "" {
        didSet { runSearch() }
    }
    @Published var searchResults: [FileEntry] = []
    @Published var isSearching = false
    @Published var searchStatusText = ""
    @Published var viewMode: ViewMode = .icons
    @Published var sortKey: SortKey = .name {
        didSet { reload() }
    }
    @Published var showHiddenFiles = false {
        didSet { reload() }
    }
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    @Published var gitRoot: URL?
    @Published var gitBranch: String?
    @Published var hoveredEntryID: String?

    private let fileManager = FileManager.default
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private var paneName = "Pane"
    private var logHandler: ((String, String) -> Void)?
    private var gitStatuses: [String: GitFileStatus] = [:]
    private var sharingPicker: NSSharingServicePicker?

    init(initialURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let url = initialURL.standardizedFileURL
        currentURL = url
        addressText = url.path
        reload(includeGit: false)
        scheduleDeferredGitReload()
    }

    func attachLogger(paneName: String, _ logger: @escaping (String, String) -> Void) {
        self.paneName = paneName
        logHandler = logger
        log("Attach", currentURL.path)
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { parentURL != nil }

    var parentURL: URL? {
        let parent = currentURL.deletingLastPathComponent()
        return parent.path == currentURL.path ? nil : parent
    }

    var selectedEntry: FileEntry? {
        guard let selectedID else { return nil }
        return filteredEntries.first { $0.id == selectedID } ?? entries.first { $0.id == selectedID }
    }

    var selectedEntries: [FileEntry] {
        let filtered = filteredEntries.filter { selectedIDs.contains($0.id) }
        return filtered.isEmpty ? entries.filter { selectedIDs.contains($0.id) } : filtered
    }

    var filteredEntries: [FileEntry] {
        searchMode == nil ? entries : searchResults
    }

    var searchMode: SearchMode? {
        SearchMode(rawQuery: searchText)
    }

    var sidebarSections: [SidebarSection] {
        var favorites: [SidebarLocation] = [
            SidebarLocation(title: "Домой", url: fileManager.homeDirectoryForCurrentUser, symbol: "house.fill")
        ]

        let desktopURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        if fileManager.fileExists(atPath: desktopURL.path) {
            favorites.append(SidebarLocation(title: "Рабочий стол", url: desktopURL, symbol: "desktopcomputer"))
        } else {
            appendLocation(.desktopDirectory, title: "Рабочий стол", symbol: "desktopcomputer", to: &favorites)
        }
        appendLocation(.downloadsDirectory, title: "Загрузки", symbol: "arrow.down.circle.fill", to: &favorites)
        appendLocation(.documentDirectory, title: "Документы", symbol: "doc.text.fill", to: &favorites)

        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let system: [SidebarLocation] = [
            SidebarLocation(title: "Программы", url: applications, symbol: "app.fill"),
            SidebarLocation(title: "Macintosh HD", url: URL(fileURLWithPath: "/", isDirectory: true), symbol: "internaldrive.fill"),
            SidebarLocation(title: "Volumes", url: URL(fileURLWithPath: "/Volumes", isDirectory: true), symbol: "externaldrive.fill")
        ]

        return [
            SidebarSection(title: "Избранное", locations: favorites),
            SidebarSection(title: "Система", locations: system)
        ]
    }

    func reload() {
        reload(includeGit: true)
    }

    private func reload(includeGit: Bool) {
        log("Reload", currentURL.path)
        if includeGit {
            reloadGitState()
        }
        do {
            entries = try readEntries(at: currentURL)
            let count = entries.count
            statusMessage = "\(count) \(itemWord(for: count))"
            selectedIDs = selectedIDs.intersection(Set(entries.map(\.id)))
            if let selectedID, !selectedIDs.contains(selectedID) {
                self.selectedID = selectedIDs.first
            }
            log("Loaded", "\(currentURL.path) · \(count) items")
            runSearch()
        } catch {
            entries = []
            searchResults = []
            searchStatusText = ""
            statusMessage = "Нет доступа"
            errorMessage = error.localizedDescription
            selectedID = nil
            selectedIDs = []
            log("Load error", "\(currentURL.path) · \(error.localizedDescription)")
        }
    }

    private func scheduleDeferredGitReload() {
        Task { @MainActor [weak self] in
            self?.reload(includeGit: true)
        }
    }

    func navigateFromAddress() {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        log("Address submit", trimmed)
        guard !trimmed.isEmpty else {
            addressText = currentURL.path
            return
        }

        let expandedPath: String
        if trimmed == "~" {
            expandedPath = fileManager.homeDirectoryForCurrentUser.path
        } else if trimmed.hasPrefix("~/") {
            let suffix = String(trimmed.dropFirst(2))
            expandedPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(suffix).path
        } else if trimmed.hasPrefix("/") {
            expandedPath = trimmed
        } else {
            expandedPath = currentURL.appendingPathComponent(trimmed).path
        }

        let url = URL(fileURLWithPath: expandedPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            errorMessage = "Путь не найден: \(url.path)"
            addressText = currentURL.path
            log("Address error", "Path not found: \(url.path)")
            return
        }

        if isDirectory.boolValue {
            navigate(to: url)
        } else {
            let parent = url.deletingLastPathComponent()
            navigate(to: parent)
            selectedID = url.path
            selectedIDs = [url.path]
        }
    }

    func navigate(to url: URL, pushHistory: Bool = true) {
        let standardized = url.standardizedFileURL
        log("Navigate", standardized.path)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: standardized.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = "Папка не найдена: \(standardized.path)"
            addressText = currentURL.path
            log("Navigate error", "Folder not found: \(standardized.path)")
            return
        }

        if pushHistory, standardized != currentURL {
            backStack.append(currentURL)
            forwardStack.removeAll()
        }

        currentURL = standardized
        addressText = standardized.path
        selectedID = nil
        selectedIDs = []
        searchText = ""
        searchResults = []
        searchStatusText = ""
        reload()
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        log("Back", previous.path)
        forwardStack.append(currentURL)
        navigate(to: previous, pushHistory: false)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        log("Forward", next.path)
        backStack.append(currentURL)
        navigate(to: next, pushHistory: false)
    }

    func goUp() {
        guard let parentURL else { return }
        log("Up", parentURL.path)
        navigate(to: parentURL)
    }

    func open(_ entry: FileEntry) {
        log("Open", entry.url.path)
        if entry.isDirectory && !entry.isPackage {
            navigate(to: entry.url)
        } else {
            NSWorkspace.shared.open(entry.url)
        }
    }

    func openSelected() {
        guard let selectedEntry else { return }
        open(selectedEntry)
    }

    func toggleHiddenFiles() {
        log("Toggle hidden", showHiddenFiles ? "Hide hidden files" : "Show hidden files")
        showHiddenFiles.toggle()
    }

    func revealInFinder(_ entry: FileEntry) {
        log("Reveal in Finder", entry.url.path)
        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
    }

    func revealSelectedInFinder() {
        let urls = selectedEntries.map(\.url)
        guard !urls.isEmpty else { return }
        log("Reveal selected", "\(urls.count) items")
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func select(_ entry: FileEntry, extending: Bool = false) {
        if extending {
            if selectedIDs.contains(entry.id) {
                selectedIDs.remove(entry.id)
                selectedID = selectedIDs.first
            } else {
                selectedIDs.insert(entry.id)
                selectedID = entry.id
            }
        } else {
            selectedID = entry.id
            selectedIDs = [entry.id]
        }
        log("Select", "\(selectedIDs.count) selected")
    }

    func selectForContextMenu(_ entry: FileEntry) {
        if selectedIDs.contains(entry.id) {
            selectedID = entry.id
        } else {
            selectedID = entry.id
            selectedIDs = [entry.id]
            log("Context select", entry.url.path)
        }
    }

    func setHovered(_ entry: FileEntry, hovering: Bool) {
        if hovering {
            hoveredEntryID = entry.id
        } else if hoveredEntryID == entry.id {
            hoveredEntryID = nil
        }
    }

    func selectHoveredForContextMenu() {
        guard let hoveredEntryID,
              let entry = filteredEntries.first(where: { $0.id == hoveredEntryID }) ?? entries.first(where: { $0.id == hoveredEntryID })
        else {
            return
        }
        selectForContextMenu(entry)
    }

    func selectAll() {
        selectedIDs = Set(filteredEntries.map(\.id))
        selectedID = filteredEntries.first?.id
        log("Select all", "\(selectedIDs.count) selected")
    }

    func clearSelection() {
        guard !selectedIDs.isEmpty || selectedID != nil else { return }
        selectedIDs = []
        selectedID = nil
        log("Clear selection")
    }

    func runSearch() {
        guard let mode = searchMode else {
            isSearching = false
            searchResults = []
            searchStatusText = ""
            return
        }

        isSearching = true
        let results = recursiveSearch(mode: mode)
        searchResults = sorted(results)
        isSearching = false
        let limited = results.count >= Self.recursiveSearchLimit ? " · limit \(Self.recursiveSearchLimit)" : ""
        searchStatusText = "\(searchResults.count) found · \(mode.description)\(limited)"
        log("Search", "\(mode.description) · \(searchResults.count) results")
    }

    func select(ids: Set<String>) {
        selectedIDs = ids
        selectedID = ids.first
        log("Marquee select", "\(ids.count) selected")
    }

    func previewSelection(ids: Set<String>) {
        selectedIDs = ids
        selectedID = ids.first
    }

    func selectedURLs() -> [URL] {
        let urls = selectedEntries.map(\.url)
        if !urls.isEmpty { return urls }
        return selectedEntry.map { [$0.url] } ?? []
    }

    func showPackageContents(_ entry: FileEntry) {
        guard entry.isPackage else { return }
        log("Show package contents", entry.url.path)
        navigate(to: entry.url)
    }

    func openWithApplications(for entry: FileEntry) -> [ApplicationOption] {
        let entries = contextEntries(containing: entry)
        guard entriesShareType(entries), let first = entries.first else { return [] }

        var common = Set(NSWorkspace.shared.urlsForApplications(toOpen: first.url))
        for entry in entries.dropFirst() {
            common.formIntersection(Set(NSWorkspace.shared.urlsForApplications(toOpen: entry.url)))
        }

        return common
            .map { ApplicationOption(url: $0, name: applicationName(for: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func openSelected(withApplicationAt applicationURL: URL) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration)
        log("Open with", "\(applicationURL.lastPathComponent) · \(urls.count) items")
    }

    func chooseApplicationForSelected() {
        let panel = NSOpenPanel()
        panel.title = "Открыть с помощью"
        panel.prompt = "Выбрать"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openSelected(withApplicationAt: url)
    }

    func copySelectedPathsToPasteboard() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
        log("Copy paths", "\(urls.count) items")
    }

    func duplicateSelected() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        do {
            for url in urls {
                let target = uniqueDuplicateURL(for: url)
                try fileManager.copyItem(at: url, to: target)
            }
            reload()
            log("Duplicate", "\(urls.count) items")
        } catch {
            errorMessage = error.localizedDescription
            log("Duplicate error", error.localizedDescription)
        }
    }

    func showInfo(for entry: FileEntry) {
        let entries = contextEntries(containing: entry)
        for entry in entries {
            let path = entry.url.path.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            tell application "Finder"
                activate
                open information window of (POSIX file "\(path)" as alias)
            end tell
            """
            do {
                try runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
                log("Get info", entry.url.path)
            } catch {
                errorMessage = error.localizedDescription
                log("Get info error", error.localizedDescription)
            }
        }
    }

    func compressSelected() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }

        do {
            let archiveURL = uniqueArchiveURL(for: urls)
            if urls.count == 1, let url = urls.first {
                try runProcess(
                    executable: "/usr/bin/ditto",
                    arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, archiveURL.path]
                )
            } else {
                guard let parent = commonParent(for: urls) else {
                    throw ExplorerError.operationFailed("Сжатие нескольких файлов поддерживается только внутри одной папки.")
                }
                try runProcess(
                    executable: "/usr/bin/zip",
                    arguments: ["-qry", archiveURL.path] + urls.map(\.lastPathComponent),
                    currentDirectory: parent
                )
            }
            reload()
            selectedID = archiveURL.path
            selectedIDs = [archiveURL.path]
            log("Compress", "\(urls.count) items -> \(archiveURL.path)")
        } catch {
            errorMessage = error.localizedDescription
            log("Compress error", error.localizedDescription)
        }
    }

    func decompressSelected() {
        let urls = selectedURLs().filter(isArchive)
        guard !urls.isEmpty else { return }

        if let archiveUtilityURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open(urls, withApplicationAt: archiveUtilityURL, configuration: configuration)
            log("Decompress", "\(urls.count) archives")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.reload()
            }
        } else {
            urls.forEach { NSWorkspace.shared.open($0) }
            log("Decompress", "\(urls.count) archives with default app")
        }
    }

    func canDecompressSelected() -> Bool {
        selectedURLs().contains(where: isArchive)
    }

    func makeAliasForSelected() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }

        do {
            for url in urls {
                let target = uniqueAliasURL(for: url)
                let data = try url.bookmarkData(
                    options: [.suitableForBookmarkFile],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try URL.writeBookmarkData(data, to: target)
            }
            reload()
            log("Alias", "\(urls.count) items")
        } catch {
            errorMessage = error.localizedDescription
            log("Alias error", error.localizedDescription)
        }
    }

    func shareSelected() {
        let urls = selectedURLs()
        guard !urls.isEmpty, let contentView = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: urls)
        sharingPicker = picker
        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        log("Share", "\(urls.count) items")
    }

    func applyTag(_ tag: FinderTagColor) {
        setTags([tag.rawValue])
    }

    func editTags() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }

        let existing = (try? urls.first?.resourceValues(forKeys: [.tagNamesKey]).tagNames)?.joined(separator: ", ") ?? ""
        let alert = NSAlert()
        alert.messageText = "Теги"
        alert.informativeText = "Введите теги через запятую."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Отмена")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = existing
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let tags = field.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        setTags(tags)
    }

    func openTerminal(at entry: FileEntry? = nil) {
        let url = terminalFolderURL(for: entry)
        let path = url.path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "cd \\"\(path)\\""
        end tell
        """
        do {
            try runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
            log("Terminal", url.path)
        } catch {
            errorMessage = error.localizedDescription
            log("Terminal error", error.localizedDescription)
        }
    }

    func rename(_ entry: FileEntry) {
        let alert = NSAlert()
        alert.messageText = "Переименовать"
        alert.informativeText = entry.name
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Отмена")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = entry.name
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != entry.name else { return }

        let target = entry.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fileManager.moveItem(at: entry.url, to: target)
            reload()
            selectedID = target.path
            selectedIDs = [target.path]
            log("Rename", "\(entry.url.path) -> \(target.path)")
        } catch {
            errorMessage = error.localizedDescription
            log("Rename error", error.localizedDescription)
        }
    }

    func moveSelectedToTrash() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Переместить в Корзину?"
        alert.informativeText = "\(urls.count) элемент(ов)"
        alert.addButton(withTitle: "В Корзину")
        alert.addButton(withTitle: "Отмена")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        NSWorkspace.shared.recycle(urls) { _, error in
            DispatchQueue.main.async {
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.log("Trash error", error.localizedDescription)
                } else {
                    self.reload()
                    self.log("Trash", "\(urls.count) items")
                }
            }
        }
    }

    func moveDroppedItems(_ urls: [URL], to targetDirectory: URL? = nil, copy: Bool = false) {
        let destination = (targetDirectory ?? currentURL).standardizedFileURL
        guard !urls.isEmpty else { return }

        do {
            for source in urls.map(\.standardizedFileURL) {
                guard source != destination else { continue }
                if source.deletingLastPathComponent().standardizedFileURL == destination, !copy {
                    continue
                }

                let target = uniqueIncomingURL(for: source, in: destination)
                if copy {
                    try fileManager.copyItem(at: source, to: target)
                } else {
                    try fileManager.moveItem(at: source, to: target)
                }
            }
            reload()
            log(copy ? "Drop copy" : "Drop move", "\(urls.count) items -> \(destination.path)")
        } catch {
            errorMessage = error.localizedDescription
            log("Drop error", error.localizedDescription)
        }
    }

    func openGitRoot() {
        guard let gitRoot else { return }
        navigate(to: gitRoot)
    }

    func copyGitStatusForSelected() {
        let lines = selectedEntries.map { entry -> String in
            "\(entry.gitStatus?.title ?? "clean")\t\(entry.url.path)"
        }
        guard !lines.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        log("Copy git status", "\(lines.count) items")
    }

    func create(_ template: CreationTemplate) {
        log("Create", template.title)
        do {
            let target = uniqueURL(for: template)
            if template == .folder {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: false)
            } else {
                let data = Data(template.contents.utf8)
                guard fileManager.createFile(atPath: target.path, contents: data) else {
                    throw ExplorerError.cannotCreate(target)
                }
            }

            reload()
            selectedID = target.path
            selectedIDs = [target.path]
            statusMessage = "Создано: \(target.lastPathComponent)"
            log("Created", target.path)
        } catch {
            errorMessage = error.localizedDescription
            log("Create error", error.localizedDescription)
        }
    }

    func entriesForParentColumn() -> [FileEntry] {
        guard let parentURL else { return [] }
        return (try? readEntries(at: parentURL)) ?? []
    }

    private var archiveUtilityURL: URL? {
        let candidates = [
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications/Archive Utility.app", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Archive Utility.app", isDirectory: true)
        ]
        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }

    private func contextEntries(containing entry: FileEntry) -> [FileEntry] {
        selectedIDs.contains(entry.id) ? selectedEntries : [entry]
    }

    private func entriesShareType(_ entries: [FileEntry]) -> Bool {
        guard let first = entries.first else { return false }
        let type = typeKey(for: first)
        return entries.allSatisfy { typeKey(for: $0) == type }
    }

    private func typeKey(for entry: FileEntry) -> String {
        if entry.isDirectory && !entry.isPackage { return "folder" }
        if entry.isPackage { return "package:\(entry.url.pathExtension.lowercased())" }
        let ext = entry.url.pathExtension.lowercased()
        return ext.isEmpty ? "file:\(entry.kind)" : "file:\(ext)"
    }

    private func applicationName(for url: URL) -> String {
        let bundle = Bundle(url: url)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let fallback = fileManager.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return displayName ?? name ?? fallback
    }

    private func uniqueArchiveURL(for urls: [URL]) -> URL {
        let directory = urls.count == 1 ? urls[0].deletingLastPathComponent() : currentURL
        let baseName: String
        if urls.count == 1, let first = urls.first {
            baseName = first.deletingPathExtension().lastPathComponent
        } else {
            baseName = "Archive"
        }

        var suffix = 0
        while true {
            let name = suffix == 0 ? "\(baseName).zip" : "\(baseName) \(suffix).zip"
            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    private func uniqueAliasURL(for source: URL) -> URL {
        let directory = source.deletingLastPathComponent()
        let base = "\(source.lastPathComponent) alias"
        var suffix = 0

        while true {
            let name = suffix == 0 ? base : "\(base) \(suffix)"
            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    private func commonParent(for urls: [URL]) -> URL? {
        guard let first = urls.first?.deletingLastPathComponent().standardizedFileURL else { return nil }
        return urls.allSatisfy { $0.deletingLastPathComponent().standardizedFileURL == first } ? first : nil
    }

    private func isArchive(_ url: URL) -> Bool {
        ["zip", "cpgz", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar"].contains(url.pathExtension.lowercased())
    }

    private func setTags(_ tags: [String]) {
        do {
            for selectedURL in selectedURLs() {
                try (selectedURL as NSURL).setResourceValue(tags, forKey: URLResourceKey.tagNamesKey)
            }
            reload()
            log("Tags", tags.isEmpty ? "Clear tags" : tags.joined(separator: ", "))
        } catch {
            errorMessage = error.localizedDescription
            log("Tags error", error.localizedDescription)
        }
    }

    private func terminalFolderURL(for entry: FileEntry?) -> URL {
        let entry = entry ?? selectedEntry
        guard let entry else { return currentURL }
        if entry.isDirectory && !entry.isPackage {
            return entry.url
        }
        return entry.url.deletingLastPathComponent()
    }

    @discardableResult
    private func runProcess(executable: String, arguments: [String], currentDirectory: URL? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw ExplorerError.operationFailed(errorOutput.isEmpty ? "Операция завершилась с ошибкой." : errorOutput)
        }
        return output
    }

    private func appendLocation(
        _ directory: FileManager.SearchPathDirectory,
        title: String,
        symbol: String,
        to locations: inout [SidebarLocation]
    ) {
        guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else { return }
        locations.append(SidebarLocation(title: title, url: url, symbol: symbol))
    }

    private func readEntries(at url: URL) throws -> [FileEntry] {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isPackageKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .localizedTypeDescriptionKey,
            .isHiddenKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
        let urls = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: options)
        let mapped = urls.compactMap { makeEntry(from: $0) }
        return sorted(mapped)
    }

    private func recursiveSearch(mode: SearchMode) -> [FileEntry] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isPackageKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .localizedTypeDescriptionKey,
            .isHiddenKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let enumerator = fileManager.enumerator(
            at: currentURL,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            return []
        }

        var results: [FileEntry] = []

        for case let url as URL in enumerator {
            if results.count >= Self.recursiveSearchLimit {
                break
            }

            guard mode.matches(url.lastPathComponent), let entry = makeEntry(from: url) else {
                continue
            }

            results.append(entry)
        }

        return results
    }

    private func makeEntry(from url: URL) -> FileEntry? {
        do {
            let values = try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isPackageKey,
                .contentModificationDateKey,
                .fileSizeKey,
                .localizedTypeDescriptionKey,
                .isHiddenKey
            ])

            let isDirectory = values.isDirectory ?? false
            let isPackage = values.isPackage ?? false
            let kind = values.localizedTypeDescription ?? (isDirectory ? "Папка" : "Файл")
            let size = values.fileSize.map(Int64.init)

            return FileEntry(
                id: url.path,
                url: url,
                name: url.lastPathComponent,
                isDirectory: isDirectory,
                isPackage: isPackage,
                size: size,
                modified: values.contentModificationDate,
                kind: kind,
                symbol: symbol(for: url, isDirectory: isDirectory, isPackage: isPackage),
                isHidden: values.isHidden ?? url.lastPathComponent.hasPrefix("."),
                gitStatus: gitStatus(for: url)
            )
        } catch {
            return nil
        }
    }

    private func sorted(_ entries: [FileEntry]) -> [FileEntry] {
        entries.sorted { left, right in
            if left.isDirectory != right.isDirectory {
                return left.isDirectory && !right.isDirectory
            }

            switch sortKey {
            case .name:
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            case .modified:
                return (left.modified ?? .distantPast) > (right.modified ?? .distantPast)
            case .kind:
                let kindCompare = left.kind.localizedStandardCompare(right.kind)
                if kindCompare != .orderedSame {
                    return kindCompare == .orderedAscending
                }
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            case .size:
                return (left.size ?? 0) > (right.size ?? 0)
            }
        }
    }

    private func symbol(for url: URL, isDirectory: Bool, isPackage: Bool) -> String {
        if isDirectory {
            return isPackage ? "shippingbox.fill" : "folder.fill"
        }

        switch url.pathExtension.lowercased() {
        case "txt", "md", "rtf": return "doc.text.fill"
        case "json", "plist": return "curlybraces.square.fill"
        case "csv", "xls", "xlsx", "numbers": return "tablecells.fill"
        case "html", "css", "js", "ts": return "chevron.left.forwardslash.chevron.right"
        case "swift": return "swift"
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "tiff": return "photo.fill"
        case "mp4", "mov", "m4v": return "film.fill"
        case "mp3", "wav", "aiff", "m4a": return "music.note"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        case "pdf": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }

    private func uniqueURL(for template: CreationTemplate) -> URL {
        let base = template.baseName
        let fileExtension = template.fileExtension
        var suffix = 1

        while true {
            let name: String
            if suffix == 1 {
                name = fileExtension.map { "\(base).\($0)" } ?? base
            } else {
                name = fileExtension.map { "\(base) \(suffix).\($0)" } ?? "\(base) \(suffix)"
            }

            let candidate = currentURL.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    private func uniqueDuplicateURL(for source: URL) -> URL {
        let directory = source.deletingLastPathComponent()
        let ext = source.pathExtension
        let base = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        var suffix = 1

        while true {
            let name: String
            if suffix == 1 {
                name = ext.isEmpty ? "\(base) copy" : "\(base) copy.\(ext)"
            } else {
                name = ext.isEmpty ? "\(base) copy \(suffix)" : "\(base) copy \(suffix).\(ext)"
            }

            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    private func uniqueIncomingURL(for source: URL, in directory: URL) -> URL {
        let baseName = source.lastPathComponent
        var candidate = directory.appendingPathComponent(baseName)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        let ext = source.pathExtension
        let base = ext.isEmpty ? baseName : source.deletingPathExtension().lastPathComponent
        var suffix = 2

        while true {
            let name = ext.isEmpty ? "\(base) \(suffix)" : "\(base) \(suffix).\(ext)"
            candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    private func reloadGitState() {
        guard let rootPath = runGit(arguments: ["rev-parse", "--show-toplevel"], at: currentURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rootPath.isEmpty
        else {
            gitRoot = nil
            gitBranch = nil
            gitStatuses = [:]
            return
        }

        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        gitRoot = root
        gitBranch = runGit(arguments: ["branch", "--show-current"], at: currentURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        gitStatuses = loadGitStatuses(root: root)
        log("Git", "\(root.path) · \(gitBranch?.isEmpty == false ? gitBranch! : "detached")")
    }

    private func loadGitStatuses(root: URL) -> [String: GitFileStatus] {
        guard let output = runGit(arguments: ["status", "--porcelain=v1", "-z"], at: root) else { return [:] }
        let chunks = output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
        var result: [String: GitFileStatus] = [:]
        var index = 0

        while index < chunks.count {
            let line = chunks[index]
            guard line.count >= 4 else {
                index += 1
                continue
            }

            let xy = String(line.prefix(2))
            let path = String(line.dropFirst(3))
            let status = statusFromPorcelain(xy)
            if let status {
                let fullPath = root.appendingPathComponent(path).standardizedFileURL.path
                result[fullPath] = status
            }

            if xy.contains("R") || xy.contains("C") {
                index += 2
            } else {
                index += 1
            }
        }

        return result
    }

    private func gitStatus(for url: URL) -> GitFileStatus? {
        let path = url.standardizedFileURL.path
        if let exact = gitStatuses[path] {
            return exact
        }

        if url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let prefix = path.hasSuffix("/") ? path : path + "/"
            return gitStatuses.first { $0.key.hasPrefix(prefix) }?.value
        }

        return nil
    }

    private func statusFromPorcelain(_ xy: String) -> GitFileStatus? {
        if xy == "??" { return .untracked }
        if xy.contains("U") || xy == "AA" || xy == "DD" { return .conflict }
        if xy.contains("A") { return .added }
        if xy.contains("D") { return .deleted }
        if xy.contains("R") { return .renamed }
        if xy.contains("M") { return .modified }
        return nil
    }

    private func runGit(arguments: [String], at url: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", url.path] + arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log("Git error", error.localizedDescription)
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func itemWord(for count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "элемент" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "элемента" }
        return "элементов"
    }

    private func log(_ action: String, _ details: String = "") {
        logHandler?("\(paneName) · \(action)", details)
    }
}
