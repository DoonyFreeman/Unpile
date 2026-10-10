import SwiftUI
import Quartz
import UnpileCore

struct NativeFilePreview: NSViewRepresentable {
    let file: FileRecord
    let text: Localizer
    func makeNSView(context: Context) -> NativePreviewHost { NativePreviewHost(frame: .zero) }
    func updateNSView(_ view: NativePreviewHost, context: Context) { view.show(file: file, text: text) }
    static func dismantleNSView(_ view: NativePreviewHost, coordinator: ()) { view.close() }
}

@MainActor
final class NativePreviewHost: NSView {
    private var preview: QLPreviewView?
    private var sourceID: UUID?
    private let message = NSTextField(wrappingLabelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        message.alignment = .center
        message.translatesAutoresizingMaskIntoConstraints = false
        addSubview(message)
        NSLayoutConstraint.activate([
            message.centerXAnchor.constraint(equalTo: centerXAnchor),
            message.centerYAnchor.constraint(equalTo: centerYAnchor),
            message.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.95)
        ])
    }
    required init?(coder: NSCoder) { nil }

    func show(file: FileRecord, text: Localizer) {
        guard file.supportsPreview, let url = file.url, FileInventory.isUnchanged(file) else {
            unavailable(text); return
        }
        setAccessibilityLabel(text("Превью: %@", file.name))
        guard sourceID != file.id else { return }
        close()
        guard let view = QLPreviewView(frame: bounds, style: .normal) else { unavailable(text); return }
        view.autostarts = false
        view.shouldCloseWithWindow = false
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor), view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor), view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        message.isHidden = true
        preview = view; sourceID = file.id
        view.previewItem = url as NSURL
    }
    func close() {
        preview?.close()
        preview?.removeFromSuperview()
        preview = nil; sourceID = nil
    }
    private func unavailable(_ text: Localizer) {
        close()
        message.stringValue = text("Превью недоступно. Закройте просмотр и начните новый разбор, чтобы обновить файл.")
        message.isHidden = false
    }
}
