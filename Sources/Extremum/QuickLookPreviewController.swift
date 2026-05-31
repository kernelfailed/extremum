import Foundation
import Quartz

@MainActor
final class QuickLookPreviewController: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = QuickLookPreviewController()

    private var urls: [URL] = []

    func show(urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls[index] as NSURL
    }
}
