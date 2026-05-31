import AppKit
import SwiftUI

@main
struct ExtremumMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        app.setActivationPolicy(.regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureAppIcon()
        configureMenuBar()
        installKeyboardMonitor()

        let rootView = FileManagerRootView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Extremum"
        window.minSize = NSSize(width: 900, height: 560)
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func configureAppIcon() {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let candidates = [
            Bundle.main.url(forResource: "ApplicationIcon", withExtension: "icns"),
            sourceRoot.appendingPathComponent("Resources/ApplicationIcon.icns")
        ].compactMap { $0 }

        for url in candidates {
            if let image = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = image
                return
            }
        }
    }

    private func installKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .rightMouseDown]) { [weak self] event in
            self?.handleEvent(event) ?? event
        }
    }

    private func handleEvent(_ event: NSEvent) -> NSEvent? {
        if event.type == .rightMouseDown {
            post(.selectHoveredForContext)
            return event
        }
        return handleKeyDown(event)
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let character = event.characters?.lowercased() ?? key

        if flags.isEmpty, event.keyCode == 53 {
            post(.clearFocus)
            return nil
        }

        if flags == [.command] {
            switch key {
            case "n":
                post(.newTab)
                return nil
            case "w":
                post(.closeTab)
                return nil
            case "l":
                post(.focusAddress)
                return nil
            case "f":
                post(.focusSearch)
                return nil
            case "r":
                post(.reload)
                return nil
            case "[":
                post(.back)
                return nil
            case "]":
                post(.forward)
                return nil
            case "o":
                post(.openSelected)
                return nil
            case "a":
                post(.selectAll)
                return nil
            case "y":
                post(.quickLookSelected)
                return nil
            default:
                if let index = tabIndex(for: key) {
                    post(.selectTab(index))
                    return nil
                }
            }

            switch event.keyCode {
            case 123:
                post(.back)
                return nil
            case 124:
                post(.forward)
                return nil
            case 125:
                post(.openSelected)
                return nil
            case 126:
                post(.up)
                return nil
            default:
                break
            }
        }

        if flags == [.command, .shift] {
            switch key {
            case "n":
                post(.create(.folder))
                return nil
            case "[":
                post(.previousTab)
                return nil
            case "]":
                post(.nextTab)
                return nil
            case ".":
                post(.toggleHidden)
                return nil
            case "r":
                post(.reload)
                return nil
            case "1":
                post(.setView(.icons))
                return nil
            case "2":
                post(.setView(.tiles))
                return nil
            case "3":
                post(.setView(.list))
                return nil
            case "4":
                post(.setView(.columns))
                return nil
            default:
                break
            }
        }

        if flags == [.command, .option] {
            if key == "," || character == "<" || event.keyCode == 43 || event.keyCode == 123 {
                post(.previousTab)
                return nil
            }

            if key == "." || character == ">" || event.keyCode == 47 || event.keyCode == 124 {
                post(.nextTab)
                return nil
            }

            switch key {
            case "d":
                post(.toggleDebug)
                return nil
            case "\\":
                post(.toggleDualPane)
                return nil
            case "1":
                post(.create(.text))
                return nil
            case "2":
                post(.create(.markdown))
                return nil
            case "3":
                post(.create(.json))
                return nil
            case "4":
                post(.create(.csv))
                return nil
            case "5":
                post(.create(.html))
                return nil
            case "6":
                post(.create(.swift))
                return nil
            case "7":
                post(.create(.plist))
                return nil
            default:
                break
            }
        }

        return event
    }

    private func tabIndex(for key: String) -> Int? {
        guard let number = Int(key), (1...9).contains(number) else { return nil }
        return number == 9 ? -1 : number - 1
    }

    private func configureMenuBar() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Extremum")
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Extremum", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Extremum", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Extremum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = addMenu("File")
        addItem("New Tab", key: "n", modifiers: [.command], command: .newTab, to: fileMenu)
        addItem("Close Tab", key: "w", modifiers: [.command], command: .closeTab, to: fileMenu)
        addItem("Previous Tab", key: "<", modifiers: [.command, .option], command: .previousTab, to: fileMenu)
        addItem("Next Tab", key: ">", modifiers: [.command, .option], command: .nextTab, to: fileMenu)
        fileMenu.addItem(.separator())
        addItem("Open Selected", key: "o", modifiers: [.command], command: .openSelected, to: fileMenu)
        addItem("Quick Look", key: "y", modifiers: [.command], command: .quickLookSelected, to: fileMenu)

        let editMenu = addMenu("Edit")
        addItem("Select All", key: "a", modifiers: [.command], command: .selectAll, to: editMenu)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")

        let goMenu = addMenu("Go")
        addItem("Back", key: "[", modifiers: [.command], command: .back, to: goMenu)
        addItem("Forward", key: "]", modifiers: [.command], command: .forward, to: goMenu)
        addItem("Up", key: String(UnicodeScalar(NSUpArrowFunctionKey)!), modifiers: [.command], command: .up, to: goMenu)
        addItem("Address Bar", key: "l", modifiers: [.command], command: .focusAddress, to: goMenu)
        addItem("Search", key: "f", modifiers: [.command], command: .focusSearch, to: goMenu)
        addItem("Reload", key: "r", modifiers: [.command], command: .reload, to: goMenu)

        let viewMenu = addMenu("View")
        addItem("Icons", key: "1", modifiers: [.command, .shift], command: .setView(.icons), to: viewMenu)
        addItem("Tiles", key: "2", modifiers: [.command, .shift], command: .setView(.tiles), to: viewMenu)
        addItem("List", key: "3", modifiers: [.command, .shift], command: .setView(.list), to: viewMenu)
        addItem("Columns", key: "4", modifiers: [.command, .shift], command: .setView(.columns), to: viewMenu)
        viewMenu.addItem(.separator())
        addItem("Toggle Hidden Files", key: ".", modifiers: [.command, .shift], command: .toggleHidden, to: viewMenu)
        addItem("Dual Pane", key: "\\", modifiers: [.command, .option], command: .toggleDualPane, to: viewMenu)

        let createMenu = addMenu("Create")
        addItem("Folder", key: "n", modifiers: [.command, .shift], command: .create(.folder), to: createMenu)
        addItem("Text File", key: "1", modifiers: [.command, .option], command: .create(.text), to: createMenu)
        addItem("Markdown", key: "2", modifiers: [.command, .option], command: .create(.markdown), to: createMenu)
        addItem("JSON", key: "3", modifiers: [.command, .option], command: .create(.json), to: createMenu)
        addItem("CSV", key: "4", modifiers: [.command, .option], command: .create(.csv), to: createMenu)
        addItem("HTML", key: "5", modifiers: [.command, .option], command: .create(.html), to: createMenu)
        addItem("Swift", key: "6", modifiers: [.command, .option], command: .create(.swift), to: createMenu)
        addItem("Plist", key: "7", modifiers: [.command, .option], command: .create(.plist), to: createMenu)

        let debugMenu = addMenu("Debug")
        addItem("Show Debug Log", key: "d", modifiers: [.command, .option], command: .toggleDebug, to: debugMenu)

        let settingsMenu = addMenu("Настройки")
        let contextMenuItem = NSMenuItem(title: "Пункты контекстного меню", action: nil, keyEquivalent: "")
        let contextMenu = NSMenu(title: "Пункты контекстного меню")
        contextMenuItem.submenu = contextMenu
        settingsMenu.addItem(contextMenuItem)

        for option in FinderContextMenuItem.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(toggleContextMenuOption(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = ContextMenuPreferences.isEnabled(option) ? .on : .off
            contextMenu.addItem(item)
        }
    }

    private func addMenu(_ title: String) -> NSMenu {
        let item = NSMenuItem()
        NSApp.mainMenu?.addItem(item)
        let menu = NSMenu(title: title)
        item.submenu = menu
        return menu
    }

    private func addItem(
        _ title: String,
        key: String,
        modifiers: NSEvent.ModifierFlags,
        command: ExplorerCommand,
        to menu: NSMenu
    ) {
        let item = NSMenuItem(title: title, action: #selector(runMenuCommand(_:)), keyEquivalent: key)
        item.target = self
        item.representedObject = command
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
    }

    @objc private func runMenuCommand(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? ExplorerCommand else { return }
        post(command)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Extremum",
            .applicationVersion: "0.1.0"
        ])
    }

    @objc private func toggleContextMenuOption(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let option = FinderContextMenuItem(rawValue: rawValue)
        else {
            return
        }

        let enabled = sender.state != .on
        ContextMenuPreferences.set(option, enabled: enabled)
        sender.state = enabled ? .on : .off
    }

    private func post(_ command: ExplorerCommand) {
        NotificationCenter.default.post(name: .explorerCommand, object: command)
    }
}
