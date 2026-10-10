import Foundation
import UnpileCore

public enum TransferState: String, Codable, Sendable {
    case waiting, processing, trashed, changed, failed, cancelled
    public var title: String {
        switch self {
        case .waiting: "Не выполнялось"
        case .processing: "Результат требует проверки"
        case .trashed: "В Корзине"
        case .changed: "Файл изменился — пропущен"
        case .failed: "Не удалось переместить"
        case .cancelled: "Отменено"
        }
    }
}

public struct JournalEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let size: Int64
    public var state: TransferState
    public init(file: FileRecord, state: TransferState = .waiting) {
        id = file.id; name = file.name; size = file.size; self.state = state
    }
}

public struct TrashJournal: Codable, Sendable {
    public let schemaVersion: Int
    public let batchID: UUID
    public var entries: [JournalEntry]
    public init(files: [FileRecord]) {
        schemaVersion = 1; batchID = UUID(); entries = files.map { JournalEntry(file: $0) }
    }
    public var requiresRecovery: Bool { entries.contains { $0.state == .waiting || $0.state == .processing } }
}

public struct JournalStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func save(_ journal: TrashJournal) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(journal).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }
    public func load() throws -> TrashJournal? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let journal = try JSONDecoder().decode(TrashJournal.self, from: Data(contentsOf: url))
        guard journal.schemaVersion == 1 else { throw JournalError.unsupportedVersion }
        return journal
    }
    public func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

public enum JournalError: Error { case unsupportedVersion }
