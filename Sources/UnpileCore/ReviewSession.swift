import Foundation

public enum Decision: String, Codable, Sendable { case keep, stage, later }

public struct DecisionChange: Codable, Sendable {
    public let id: UUID
    public let previous: Decision?
    public init(id: UUID, previous: Decision?) { self.id = id; self.previous = previous }
}

/// A decision changes session state only. This type never writes to user files.
public struct ReviewSession: Sendable {
    public let files: [FileRecord]
    public private(set) var decisions: [UUID: Decision] = [:]
    public private(set) var history: [DecisionChange] = []
    private var trashed: Set<UUID> = []

    public init(files: [FileRecord], limit: Int = 20) {
        self.files = Array(files.prefix(max(0, limit)))
    }
    public init(restoring files: [FileRecord], decisions: [UUID: Decision], history: [DecisionChange]) {
        self.files = files
        let ids = Set(files.map(\.id))
        self.decisions = decisions.filter { ids.contains($0.key) }
        self.history = history.filter { ids.contains($0.id) }
    }
    public var remainingFiles: [FileRecord] { files.filter { !trashed.contains($0.id) } }
    public var current: FileRecord? { files.first { decisions[$0.id] == nil && !trashed.contains($0.id) } }
    public var upcoming: [FileRecord] { Array(files.filter { decisions[$0.id] == nil && !trashed.contains($0.id) }.dropFirst().prefix(4)) }
    public var staged: [FileRecord] { files.filter { decisions[$0.id] == .stage } }
    public var stagedBytes: Int64 { staged.reduce(0) { let sum = $0.addingReportingOverflow($1.size); return sum.overflow ? Int64.max : sum.partialValue } }
    public var reviewedCount: Int { decisions.count + trashed.count }
    public var canUndo: Bool { !history.isEmpty }
    public var isComplete: Bool { current == nil }

    public mutating func decide(_ decision: Decision) {
        guard let current else { return }
        history.append(DecisionChange(id: current.id, previous: decisions[current.id]))
        decisions[current.id] = decision
    }
    public mutating func keepCandidate(_ id: UUID) {
        guard decisions[id] == .stage else { return }
        history.append(DecisionChange(id: id, previous: .stage))
        decisions[id] = .keep
    }
    public mutating func undo() {
        guard let change = history.popLast() else { return }
        decisions[change.id] = change.previous
    }
    public mutating func finishTransfer(_ successfulIDs: Set<UUID>) {
        for id in successfulIDs where decisions[id] == .stage {
            decisions[id] = nil
            trashed.insert(id)
        }
        // Undo is a decision-only operation, never an implicit filesystem restore.
        history.removeAll()
    }
}
