import Foundation

public struct ReviewPreferences: Codable, Equatable, Sendable {
    public var order: FileOrder
    public var includeRecent: Bool
    public var limit: Int
    public init(order: FileOrder = .largest, includeRecent: Bool = false, limit: Int = 20) {
        self.order = order; self.includeRecent = includeRecent; self.limit = limit
    }
}

/// Relative names are matched to a fresh inventory, never turned into operation URLs.
public struct SavedFileVersion: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let fingerprint: FileFingerprint
    public init(_ file: FileRecord) throws {
        guard let fingerprint = file.fingerprint, let url = file.url,
              file.name == url.lastPathComponent, Self.isSafeName(file.name) else { throw ReviewStateError.invalidState }
        id = file.id; name = file.name; self.fingerprint = fingerprint
    }
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }
    var key: VersionKey { VersionKey(name: name, fingerprint: fingerprint) }
    func matches(_ file: FileRecord) -> Bool { file.name == name && file.fingerprint == fingerprint }
}

struct VersionKey: Hashable {
    let name: String
    let fingerprint: FileFingerprint
}

public struct SavedDecision: Codable, Sendable {
    public let id: UUID
    public let decision: Decision
}

public struct ReviewRestoration: Sendable {
    public let session: ReviewSession
    public let kept: [SavedFileVersion]
    public let invalidatedCount: Int
}

public enum ReviewStateError: Error { case invalidState, unsupportedVersion, differentFolder, tooLarge }

public struct ReviewState: Codable, Sendable {
    public let schemaVersion: Int
    public let folderIdentity: FolderFingerprint
    public let preferences: ReviewPreferences
    public let files: [SavedFileVersion]
    public let decisions: [SavedDecision]
    public let history: [DecisionChange]
    public let kept: [SavedFileVersion]

    public init(folderIdentity: FolderFingerprint, preferences: ReviewPreferences, session: ReviewSession,
                kept: [SavedFileVersion]) throws {
        schemaVersion = 1; self.folderIdentity = folderIdentity; self.preferences = preferences
        files = try session.remainingFiles.map(SavedFileVersion.init)
        let ids = Set(files.map(\.id))
        decisions = session.decisions.filter { ids.contains($0.key) }.map { SavedDecision(id: $0.key, decision: $0.value) }
        history = session.history.filter { ids.contains($0.id) }
        // Replacing current entries also makes Undo remove a previously remembered Keep.
        let currentKeys = Set(files.map(\.key))
        self.kept = kept.filter { !currentKeys.contains($0.key) } + files.filter { session.decisions[$0.id] == .keep }
        try validate()
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw ReviewStateError.unsupportedVersion }
        let ids = Set(files.map(\.id))
        guard [20, 50, 100].contains(preferences.limit), files.count <= preferences.limit, kept.count <= 100_000,
              history.count <= 1_000, ids.count == files.count,
              Set(files.map(\.name)).count == files.count,
              Set(kept.map(\.name)).count == kept.count,
              Set(kept.map(\.id)).count == kept.count,
              Set(decisions.map(\.id)).count == decisions.count,
              decisions.allSatisfy({ ids.contains($0.id) }), history.allSatisfy({ ids.contains($0.id) }),
              (files + kept).allSatisfy({ SavedFileVersion.isSafeName($0.name) && $0.fingerprint.size >= 0 })
        else { throw ReviewStateError.invalidState }
    }

    public func restore(inventory: [FileRecord], folderIdentity: FolderFingerprint) throws -> ReviewRestoration {
        try validate()
        guard self.folderIdentity == folderIdentity else { throw ReviewStateError.differentFolder }
        var fresh: [VersionKey: FileRecord] = [:]
        var byName: [String: FileRecord] = [:]
        for file in inventory {
            if let fingerprint = file.fingerprint {
                fresh[VersionKey(name: file.name, fingerprint: fingerprint)] = file
                byName[file.name] = file
            }
        }
        let records = files.compactMap { saved -> FileRecord? in
            // A changed file starts with a fresh UUID and no inherited decision or Undo.
            guard let file = fresh[saved.key] else { return byName[saved.name] }
            return FileRecord(id: saved.id, name: file.name, url: file.url, size: file.size, modified: file.modified,
                typeIdentifier: file.typeIdentifier, resourceIdentifier: file.resourceIdentifier, fingerprint: file.fingerprint)
        }
        let validIDs = Set(records.map(\.id))
        let restoredDecisions = Dictionary(uniqueKeysWithValues: decisions.filter { validIDs.contains($0.id) }.map { ($0.id, $0.decision) })
        return ReviewRestoration(session: ReviewSession(restoring: records, decisions: restoredDecisions, history: history),
            kept: kept.filter { fresh[$0.key] != nil }, invalidatedCount: files.filter { fresh[$0.key] == nil }.count)
    }

    public static func pending(inventory: [FileRecord], kept: [SavedFileVersion]) -> [FileRecord] {
        let keys = Set(kept.map(\.key))
        return inventory.filter { file in
            guard let fingerprint = file.fingerprint else { return true }
            return !keys.contains(VersionKey(name: file.name, fingerprint: fingerprint))
        }
    }
}
