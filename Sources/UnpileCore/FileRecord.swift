import Foundation
import UniformTypeIdentifiers

public struct FileRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let url: URL?
    public let size: Int64
    public let modified: Date
    public let typeIdentifier: String?
    public let resourceIdentifier: String?
    public let fingerprint: FileFingerprint?

    public init(id: UUID = UUID(), name: String, url: URL? = nil, size: Int64,
                modified: Date, typeIdentifier: String? = nil, resourceIdentifier: String? = nil,
                fingerprint: FileFingerprint? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.size = max(0, size)
        self.modified = modified
        self.typeIdentifier = typeIdentifier
        self.resourceIdentifier = resourceIdentifier
        self.fingerprint = fingerprint
    }

    public var type: UTType? { typeIdentifier.flatMap(UTType.init) ?? UTType(filenameExtension: (name as NSString).pathExtension) }
    public var supportsPreview: Bool {
        guard let type else { return false }
        // Active documents never go through a web view or automatic Quick Look.
        if type.conforms(to: .svg) || type.conforms(to: .html) { return false }
        return type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .movie) || type.conforms(to: .audio)
    }
    public var icon: String {
        guard let type else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) { return "video" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .archive) { return "archivebox" }
        return "doc"
    }
    public var typeLabel: String { type?.localizedDescription ?? "Файл" }
    public var formattedSize: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

public enum FileOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case largest, oldest, name
    public var id: Self { self }
    public var title: String {
        switch self {
        case .largest: "Крупные сначала"
        case .oldest: "Старые сначала"
        case .name: "По имени"
        }
    }
    public func sorted(_ files: [FileRecord]) -> [FileRecord] {
        files.sorted { left, right in
            switch self {
            case .largest where left.size != right.size: return left.size > right.size
            case .oldest where left.modified != right.modified: return left.modified < right.modified
            default: return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
        }
    }
}
