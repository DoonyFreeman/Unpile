import Foundation
import UnpileCore
import UnpileFilesystem

final class TransferSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded = 0
    var calls: Int { lock.withLock { recorded } }
    func record() { lock.withLock { recorded += 1 } }
}

struct FakeTrashDriver: TrashDriver {
    let spy: TransferSpy
    let store: JournalStore
    var failName: String? = nil
    func move(_ file: FileRecord, root: URL, rootIdentity: FolderFingerprint) throws {
        guard try store.load()?.entries.first(where: { $0.id == file.id })?.state == .processing else {
            throw CheckFailure("No persisted intent before operation")
        }
        spy.record()
        if file.name == failName { throw CheckFailure("Synthetic permission failure") }
        // This test adapter never mutates source files or the user's Trash.
    }
}

struct TransferChecks {
    static func withFixture(_ body: (URL, [FileRecord], FolderFingerprint, JournalStore) throws -> Void) throws {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("UnpileTransferTest-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["one.txt", "two.txt"] {
            let url = root.appendingPathComponent(name)
            try Data("Synthetic transfer fixture".utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-200_000)], ofItemAtPath: url.path)
        }
        let files = try FileInventory.scan(folder: root).files.sorted { $0.name < $1.name }
        let identity = FileInventory.folderFingerprint(root)!
        let store = JournalStore(url: root.appendingPathComponent("state/journal.json"))
        try body(root, files, identity, store)
    }
    static func journalPrecedesOperationsAndPartialFailuresRemainDistinct() throws {
        try withFixture { root, files, identity, store in
            let spy = TransferSpy()
            let report = try TrashExecutor(driver: FakeTrashDriver(spy: spy, store: store, failName: "two.txt"), journalStore: store)
                .execute(files: files, root: root, rootIdentity: identity)
            try expect(spy.calls == 2, "Driver not called")
            try expect(report.entries.map(\.state) == [.trashed, .failed], "Partial success was lost")
            try expect(!report.needsRecovery && report.successfulIDs == [files[0].id], "Incorrect success report")
            try expect(try store.load() == nil, "Completed journal retained")
        }
    }
    static func changedFilesAndLinksNeverReachDriver() throws {
        try withFixture { root, files, identity, store in
            try Data("Changed fixture with another size".utf8).write(to: files[0].url!)
            try FileManager.default.removeItem(at: files[1].url!)
            try FileManager.default.createSymbolicLink(at: files[1].url!, withDestinationURL: files[0].url!)
            let spy = TransferSpy()
            let report = try TrashExecutor(driver: FakeTrashDriver(spy: spy, store: store), journalStore: store)
                .execute(files: files, root: root, rootIdentity: identity)
            try expect(spy.calls == 0 && report.entries.allSatisfy { $0.state == .changed }, "Changed object reached driver")
            try expect(!FileInventory.isUnchanged(files[0]) && !FileInventory.isUnchanged(files[1]), "Preview accepted stale version")
        }
    }
    static func failedJournalWritePreventsAnyOperation() throws {
        try withFixture { root, files, identity, _ in
            let blocked = root.appendingPathComponent("blocker")
            try Data("Synthetic blocker".utf8).write(to: blocked)
            let store = JournalStore(url: blocked.appendingPathComponent("journal.json"))
            let spy = TransferSpy()
            do {
                _ = try TrashExecutor(driver: FakeTrashDriver(spy: spy, store: store), journalStore: store)
                    .execute(files: files, root: root, rootIdentity: identity)
                throw CheckFailure("Write failure was ignored")
            } catch is CheckFailure { throw CheckFailure("Expected storage failure") }
            catch { try expect(spy.calls == 0, "Driver ran without a journal") }
        }
    }
    static func unresolvedJournalBlocksAutomaticRepeat() throws {
        try withFixture { root, files, identity, store in
            var journal = TrashJournal(files: files)
            journal.entries[0].state = .processing
            try store.save(journal)
            let spy = TransferSpy()
            do {
                _ = try TrashExecutor(driver: FakeTrashDriver(spy: spy, store: store), journalStore: store)
                    .execute(files: files, root: root, rootIdentity: identity)
                throw CheckFailure("Unresolved operation was retried")
            } catch TransferError.recoveryRequired { try expect(spy.calls == 0, "Unresolved operation reached driver") }
        }
    }
    static func transferredFilesDoNotReturnToQueueOrUndo() throws {
        let record = SessionChecks.file("one", size: .max)
        let second = SessionChecks.file("two", size: .max)
        var session = ReviewSession(files: [record, second])
        session.decide(.stage); session.decide(.stage)
        try expect(session.stagedBytes == .max, "Size overflow")
        session.finishTransfer([record.id])
        try expect(session.current == nil && !session.canUndo, "Transferred file can be undone or queued")
        try expect(session.staged.map(\.id) == [second.id] && session.reviewedCount == 2, "Remaining candidates lost")
    }
}
