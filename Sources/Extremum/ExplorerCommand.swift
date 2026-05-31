import Foundation

enum ExplorerCommand {
    case newTab
    case closeTab
    case selectTab(Int)
    case nextTab
    case previousTab
    case toggleDualPane
    case toggleDebug
    case focusAddress
    case focusSearch
    case clearFocus
    case reload
    case back
    case forward
    case up
    case selectAll
    case selectHoveredForContext
    case openSelected
    case quickLookSelected
    case toggleHidden
    case setView(ViewMode)
    case create(CreationTemplate)
}

extension Notification.Name {
    static let explorerCommand = Notification.Name("Extremum.explorerCommand")
}
