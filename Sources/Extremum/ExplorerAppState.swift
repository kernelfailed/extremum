import Foundation

enum PaneSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Левая"
        case .right: "Правая"
        }
    }
}

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let action: String
    let details: String

    var time: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

@MainActor
final class ExplorerTab: ObservableObject, Identifiable {
    let id = UUID()
    let left: FileExplorerModel
    let right: FileExplorerModel

    init(initialURL: URL, logger: @escaping (String, String) -> Void) {
        left = FileExplorerModel(initialURL: initialURL)
        right = FileExplorerModel(initialURL: initialURL)
        left.attachLogger(paneName: "Left", logger)
        right.attachLogger(paneName: "Right", logger)
    }

    var title: String {
        let value = left.currentURL.lastPathComponent
        return value.isEmpty ? "/" : value
    }
}

@MainActor
final class ExplorerAppState: ObservableObject {
    @Published var tabs: [ExplorerTab] = []
    @Published var selectedTabID: ExplorerTab.ID?
    @Published var activePane: PaneSide = .left
    @Published var dualPaneEnabled = false
    @Published var logs: [DebugLogEntry] = []

    init() {
        addTab(initialURL: FileManager.default.homeDirectoryForCurrentUser, select: true)
        log("App", "Extremum started")
    }

    var selectedTab: ExplorerTab {
        if let selectedTabID, let tab = tabs.first(where: { $0.id == selectedTabID }) {
            return tab
        }
        return tabs[0]
    }

    var activeModel: FileExplorerModel {
        model(for: activePane)
    }

    func model(for pane: PaneSide) -> FileExplorerModel {
        switch pane {
        case .left:
            selectedTab.left
        case .right:
            selectedTab.right
        }
    }

    func addTab(initialURL: URL? = nil, select: Bool = true) {
        let url = initialURL ?? (tabs.isEmpty ? FileManager.default.homeDirectoryForCurrentUser : activeModel.currentURL)
        let tab = ExplorerTab(initialURL: url, logger: { [weak self] action, details in
            self?.log(action, details)
        })
        tabs.append(tab)
        if select {
            selectedTabID = tab.id
            activePane = .left
        }
        log("Tab", "New tab: \(url.path)")
    }

    func closeSelectedTab() {
        guard tabs.count > 1, let selectedTabID else {
            log("Tab", "Close skipped: single tab")
            return
        }

        guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        let removed = tabs.remove(at: index)
        let nextIndex = min(index, tabs.count - 1)
        self.selectedTabID = tabs[nextIndex].id
        activePane = .left
        log("Tab", "Closed tab: \(removed.title)")
    }

    func selectTab(_ tab: ExplorerTab) {
        selectedTabID = tab.id
        activePane = .left
        log("Tab", "Selected tab: \(tab.title)")
    }

    func selectTab(at index: Int) {
        guard !tabs.isEmpty else { return }
        let resolvedIndex = index == -1 ? tabs.count - 1 : index
        guard tabs.indices.contains(resolvedIndex) else {
            log("Tab", "Select skipped: index \(index + 1)")
            return
        }
        selectTab(tabs[resolvedIndex])
    }

    func selectNextTab() {
        guard !tabs.isEmpty else { return }
        let currentIndex = tabs.firstIndex { $0.id == selectedTabID } ?? 0
        selectTab(tabs[(currentIndex + 1) % tabs.count])
    }

    func selectPreviousTab() {
        guard !tabs.isEmpty else { return }
        let currentIndex = tabs.firstIndex { $0.id == selectedTabID } ?? 0
        selectTab(tabs[(currentIndex - 1 + tabs.count) % tabs.count])
    }

    func setActivePane(_ pane: PaneSide) {
        activePane = pane
        log("Pane", "Active pane: \(pane.title)")
    }

    func toggleDualPane() {
        dualPaneEnabled.toggle()
        log("Pane", dualPaneEnabled ? "Dual pane enabled" : "Dual pane disabled")
    }

    func log(_ action: String, _ details: String = "") {
        logs.append(DebugLogEntry(date: Date(), action: action, details: details))
        if logs.count > 700 {
            logs.removeFirst(logs.count - 700)
        }
    }
}
