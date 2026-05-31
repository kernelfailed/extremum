import AppKit
@preconcurrency import QuickLookThumbnailing
import SwiftUI

struct FileThumbnailView: View {
    let entry: FileEntry
    let size: CGFloat

    @State private var image: NSImage?
    @State private var representedPath: String?
    @State private var thumbnailTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                FileSymbolView(entry: entry, size: size)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let status = entry.gitStatus {
                GitStatusBadge(status: status)
            }
        }
        .frame(width: size, height: size)
        .onAppear(perform: load)
        .onChange(of: entry.id) { _ in
            image = nil
            load()
        }
        .onDisappear {
            thumbnailTask?.cancel()
            thumbnailTask = nil
        }
    }

    private func load() {
        let url = entry.url
        let path = url.path
        let targetSize = CGSize(width: size * 2, height: size * 2)
        let scale = NSScreen.main?.backingScaleFactor ?? 2

        if representedPath != path {
            representedPath = path
            image = nil
        } else if image != nil {
            return
        }

        if entry.isPackage || url.pathExtension.lowercased() == "app" {
            image = NSWorkspace.shared.icon(forFile: path)
            return
        }

        thumbnailTask?.cancel()
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: targetSize,
            scale: scale,
            representationTypes: .all
        )

        thumbnailTask = Task { @MainActor in
            let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard !Task.isCancelled, representedPath == path else { return }
            image = thumbnail?.nsImage ?? NSWorkspace.shared.icon(forFile: path)
        }
    }
}

struct GitStatusBadge: View {
    let status: GitFileStatus

    var body: some View {
        Image(systemName: status.symbol)
            .font(.system(size: 13, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(status.color, Color(nsColor: .textBackgroundColor))
            .background(Circle().fill(Color(nsColor: .textBackgroundColor)))
            .help(status.title)
    }
}

extension GitFileStatus {
    var color: Color {
        switch self {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .untracked: return .secondary
        case .conflict: return .red
        }
    }
}

struct FileSymbolView: View {
    let entry: FileEntry
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(size * 0.14, 8))
                .fill(entry.tint.opacity(entry.isDirectory ? 0.15 : 0.09))
            Image(systemName: entry.symbol)
                .font(.system(size: size * 0.62, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(entry.tint)
        }
    }
}
