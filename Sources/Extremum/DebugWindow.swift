import SwiftUI

final class DebugWindowController: NSWindowController {
    init(appState: ExplorerAppState) {
        let rootView = DebugLogWindow(appState: appState)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 420),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Extremum Debug Log"
        window.minSize = NSSize(width: 560, height: 280)
        window.contentView = NSHostingView(rootView: rootView)
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct DebugLogWindow: View {
    @ObservedObject var appState: ExplorerAppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Debug Log")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(appState.logs.count) events")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.logs) { log in
                        HStack(alignment: .top, spacing: 10) {
                            Text(log.time)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .leading)

                            Text(log.action)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 160, alignment: .leading)

                            Text(log.details)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)

                        Divider()
                    }
                }
            }
        }
    }
}
