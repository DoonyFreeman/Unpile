import Foundation
import UnpileCore

public protocol TrashDriver: Sendable {
    /// Validate inside coordination, immediately before using the system Trash API.
    func move(_ file: FileRecord, root: URL, rootIdentity: FolderFingerprint) throws
}

public enum TransferError: Error { case changed, outsideFolder, recoveryRequired }

public struct SystemTrashDriver: TrashDriver {
    public init() {}
    public func move(_ file: FileRecord, root: URL, rootIdentity: FolderFingerprint) throws {
        guard let source = file.url,
              source.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else { throw TransferError.outsideFolder }
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: (any Error)?
        var completed = false
        coordinator.coordinate(writingItemAt: source, options: .forDeleting, error: &coordinationError) { coordinatedURL in
            do {
                guard coordinatedURL.standardizedFileURL == source.standardizedFileURL,
                      FileInventory.folderFingerprint(root) == rootIdentity,
                      FileInventory.isUnchanged(file) else { throw TransferError.changed }
                var trashURL: NSURL?
                try FileManager.default.trashItem(at: coordinatedURL, resultingItemURL: &trashURL)
                completed = true
            } catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
        guard completed else { throw TransferError.changed }
    }
}

public struct TransferReport: Sendable {
    public let entries: [JournalEntry]
    public let needsRecovery: Bool
    public var successfulIDs: Set<UUID> { Set(entries.filter { $0.state == .trashed }.map(\.id)) }
    public var successfulBytes: Int64 { entries.filter { $0.state == .trashed }.reduce(0) { let sum = $0.addingReportingOverflow($1.size); return sum.overflow ? Int64.max : sum.partialValue } }
}

public struct TrashExecutor<Driver: TrashDriver>: Sendable {
    public let driver: Driver
    public let journalStore: JournalStore
    public init(driver: Driver, journalStore: JournalStore) { self.driver = driver; self.journalStore = journalStore }

    public func execute(files: [FileRecord], root: URL, rootIdentity: FolderFingerprint,
                        progress: @Sendable (Int, Int) -> Void = { _, _ in }) throws -> TransferReport {
        // Approval is supplied by the caller; this executor is never invoked from a swipe.
        try FileInventory.validateFolder(root)
        if try journalStore.load()?.requiresRecovery == true { throw TransferError.recoveryRequired }
        var journal = TrashJournal(files: files)
        try journalStore.save(journal)
        for index in files.indices {
            if Task.isCancelled { break }
            journal.entries[index].state = .processing
            try journalStore.save(journal) // failure here prevents the file operation
            do {
                guard FileInventory.folderFingerprint(root) == rootIdentity,
                      let url = files[index].url,
                      url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL,
                      FileInventory.isUnchanged(files[index]) else { throw TransferError.changed }
                try driver.move(files[index], root: root, rootIdentity: rootIdentity)
                journal.entries[index].state = .trashed
            } catch TransferError.changed { journal.entries[index].state = .changed }
            catch { journal.entries[index].state = .failed }
            do { try journalStore.save(journal) }
            catch {
                // The on-disk intent may still be processing. Never retry automatically.
                journal.entries[index].state = .processing
                return TransferReport(entries: journal.entries, needsRecovery: true)
            }
            progress(index + 1, files.count)
        }
        for index in journal.entries.indices where journal.entries[index].state == .waiting {
            journal.entries[index].state = .cancelled
        }
        do { try journalStore.save(journal) }
        catch { return TransferReport(entries: journal.entries, needsRecovery: true) }
        let unfinished = journal.requiresRecovery
        if !unfinished {
            do { try journalStore.clear() }
            catch { return TransferReport(entries: journal.entries, needsRecovery: true) }
        }
        return TransferReport(entries: journal.entries, needsRecovery: unfinished)
    }
}
