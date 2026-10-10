import AppKit
import SwiftUI
@preconcurrency import QuickLookThumbnailing
import UnpileCore

@MainActor
final class ThumbnailModel: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var isLoading = false
    private var request: QLThumbnailGenerator.Request?
    private var generation = UUID()

    func load(_ file: FileRecord) {
        if let request { QLThumbnailGenerator.shared.cancel(request) }
        request = nil
        image = nil
        isLoading = false
        let token = UUID()
        generation = token
        guard file.supportsPreview, let url = file.url, FileInventory.isUnchanged(file) else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 1100, height: 650), scale: 1, representationTypes: .thumbnail)
        self.request = request
        isLoading = true
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            let cgImage = representation?.cgImage
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.image = cgImage.map { NSImage(cgImage: $0, size: .zero) }
                self.isLoading = false
                self.request = nil
            }
        }
    }
}
