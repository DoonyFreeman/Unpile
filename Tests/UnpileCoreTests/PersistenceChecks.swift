import Foundation
import UnpileCore
import UnpileFilesystem

struct PersistenceChecks {
    static func withFixture(_ check: (URL, [FileRecord], FolderFingerprint, ReviewStore) throws -> Void) throws {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("UnpilePersistence-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for (index, name) in ["one.txt", "two.txt", "three.txt"].enumerated() {
            try Data(repeating: UInt8(65 + index), count: (index + 1) * 100).write(to: root.appendingPathComponent(name))
        }
        guard let identity = FileInventory.folderFingerprint(root) else { throw CheckFailure("Missing fixture identity") }
        let files = FileOrder.name.sorted(try FileInventory.scan(folder: root, includeRecent: true).files)
        try check(root, files, identity, ReviewStore(url: root.appendingPathComponent("private/review-state.json")))
    }

    static func resumeDecisionsAndUndo() throws {
        try withFixture { root, files, identity, store in
            var session = ReviewSession(files: files)
            session.decide(.stage); session.decide(.keep)
            let preferences = ReviewPreferences(order: .name, includeRecent: true, limit: 50)
            try store.save(ReviewState(folderIdentity: identity, preferences: preferences, session: session, kept: []))
            guard let loaded = try store.load() else { throw CheckFailure("State missing") }
            let fresh = try FileInventory.scan(folder: root, includeRecent: true).files
            var restored = try loaded.restore(inventory: fresh, folderIdentity: identity).session
            try expect(restored.staged.map(\.id) == [files[0].id], "Candidates lost")
            try expect(restored.current?.id == files[2].id && restored.reviewedCount == 2, "Queue position lost")
            try expect(loaded.preferences == preferences, "Preferences lost")
            restored.undo()
            try expect(restored.current?.id == files[1].id, "Undo was not restored")
            try store.save(ReviewState(folderIdentity: identity, preferences: preferences, session: restored, kept: loaded.kept))
            try expect(try store.load()?.kept.isEmpty == true, "Undo did not forget Keep")
            try expect(try Data(contentsOf: files[0].url!).count == 100, "Restoring touched source")
        }
    }

    static func keepPersistsWhileLaterReturns() throws {
        try withFixture { root, files, identity, store in
            var session = ReviewSession(files: files)
            session.decide(.keep); session.decide(.later); session.decide(.keep)
            try store.save(ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: session, kept: []))
            let loaded = try store.load()!
            let restored = try loaded.restore(inventory: FileInventory.scan(folder: root, includeRecent: true).files, folderIdentity: identity)
            let pending = ReviewState.pending(inventory: files, kept: restored.kept)
            try expect(pending.map(\.id) == [files[1].id], "Keep or Later policy failed")
            let next = ReviewSession(files: pending)
            try store.save(ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: next, kept: restored.kept))
            try expect(try store.load()?.kept.count == 2, "Next batch forgot prior Keep")
            let reconsidered = ReviewSession(files: files)
            let state = try ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: reconsidered, kept: [])
            try expect(state.kept.isEmpty && state.decisions.isEmpty, "Reconsider inherited decisions")
        }
    }

    static func changedVersionsNeverInheritIntent() throws {
        try withFixture { root, files, identity, store in
            var session = ReviewSession(files: files)
            session.decide(.stage); session.decide(.keep)
            try store.save(ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: session, kept: []))
            try Data("Changed synthetic version with a different size".utf8).write(to: files[0].url!, options: .atomic)
            try FileManager.default.removeItem(at: files[1].url!)
            try FileManager.default.createSymbolicLink(at: files[1].url!, withDestinationURL: files[2].url!)
            let loaded = try store.load()!
            let fresh = try FileInventory.scan(folder: root, includeRecent: true).files
            let restored = try loaded.restore(inventory: fresh, folderIdentity: identity)
            try expect(restored.session.staged.isEmpty && restored.kept.isEmpty, "Stale intent restored")
            try expect(restored.session.current?.name == files[0].name && restored.session.current?.id != files[0].id, "Changed file did not get a fresh decision")
            try expect(!restored.session.canUndo && restored.invalidatedCount == 2, "Unsafe history survived")
            let other = root.appendingPathComponent("another-folder")
            try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
            do { _ = try loaded.restore(inventory: fresh, folderIdentity: FileInventory.folderFingerprint(other)!) }
            catch ReviewStateError.differentFolder { return }
            throw CheckFailure("Another folder inherited decisions")
        }
    }

    static func invalidStateNeverCreatesOperationURLs() throws {
        try withFixture { _, files, identity, store in
            let state = try ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: ReviewSession(files: files), kept: [])
            let original = try JSONEncoder().encode(state)
            var object = try JSONSerialization.jsonObject(with: original) as! [String: Any]
            for mutation in ["path", "duplicate", "schema", "limit"] {
                var poisoned = object
                var savedFiles = poisoned["files"] as! [[String: Any]]
                switch mutation {
                case "path": savedFiles[0]["name"] = "../outside.txt"; poisoned["files"] = savedFiles
                case "duplicate": savedFiles.append(savedFiles[0]); poisoned["files"] = savedFiles
                case "schema": poisoned["schemaVersion"] = 99
                default: var prefs = poisoned["preferences"] as! [String: Any]; prefs["limit"] = 100_000; poisoned["preferences"] = prefs
                }
                let data = try JSONSerialization.data(withJSONObject: poisoned)
                try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: store.url)
                do { _ = try store.load(); throw CheckFailure("Invalid state accepted") }
                catch is ReviewStateError { }
                try expect(try Data(contentsOf: store.url) == data, "Invalid state was silently overwritten")
            }
            try Data(repeating: 65, count: 10_000_001).write(to: store.url)
            do { _ = try store.load(); throw CheckFailure("Oversized state accepted") }
            catch ReviewStateError.tooLarge { }
            object.removeAll()
        }
    }

    static func privateStorageAndFailurePreserveSource() throws {
        try withFixture { root, files, identity, store in
            let state = try ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: ReviewSession(files: files), kept: [])
            try store.save(state)
            let attributes = try FileManager.default.attributesOfItem(atPath: store.url.path)
            try expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "State permissions too broad")
            let directory = try FileManager.default.attributesOfItem(atPath: store.url.deletingLastPathComponent().path)
            try expect((directory[.posixPermissions] as? NSNumber)?.intValue == 0o700, "Directory permissions too broad")
            let encoded = String(decoding: try Data(contentsOf: store.url), as: UTF8.self)
            try expect(!encoded.contains(root.path) && !encoded.contains("resourceIdentifier") && !encoded.contains("typeIdentifier"), "Unnecessary data persisted")
            let accepted = try Data(contentsOf: store.url)
            let orphan = store.url.deletingLastPathComponent().appendingPathComponent(".review-\(UUID()).tmp")
            let unrelated = store.url.deletingLastPathComponent().appendingPathComponent("unrelated-fixture.txt")
            try Data("Synthetic interrupted write".utf8).write(to: orphan)
            try Data("Unrelated synthetic fixture".utf8).write(to: unrelated)
            _ = try store.load()
            try expect(!FileManager.default.fileExists(atPath: orphan.path) && FileManager.default.fileExists(atPath: unrelated.path), "Transient cleanup touched unrelated data")
            var candidate = ReviewSession(files: files); candidate.decide(.stage)
            let changed = try ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: candidate, kept: [])
            let parent = store.url.deletingLastPathComponent()
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path) }
            do { try store.save(changed); throw CheckFailure("Unwritable state was replaced") }
            catch is CheckFailure { throw CheckFailure("Unwritable state was replaced") }
            catch { }
            try expect(try Data(contentsOf: store.url) == accepted, "Failed save replaced accepted decisions")
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
            let invalidParent = root.appendingPathComponent("blocked-by-file")
            try Data("Synthetic obstruction".utf8).write(to: invalidParent)
            let blocked = ReviewStore(url: invalidParent.appendingPathComponent("state.json"))
            do { try blocked.save(state); throw CheckFailure("Blocked write succeeded") }
            catch is CheckFailure { throw CheckFailure("Blocked write succeeded") }
            catch { }
            try expect(try Data(contentsOf: files[0].url!).count == 100, "Storage failure changed source")
            try Data("Synthetic interrupted write".utf8).write(to: orphan)
            try store.clear()
            try expect(try store.load() == nil && !FileManager.default.fileExists(atPath: orphan.path) && FileManager.default.fileExists(atPath: unrelated.path) && FileManager.default.fileExists(atPath: files[0].url!.path), "Reset touched source or kept fragments")
        }
    }

    static func transferredEntriesCannotReappearFromSnapshot() throws {
        try withFixture { _, files, identity, store in
            var session = ReviewSession(files: files)
            session.decide(.stage); session.decide(.keep)
            session.finishTransfer([files[0].id])
            try store.save(ReviewState(folderIdentity: identity, preferences: ReviewPreferences(), session: session, kept: []))
            let loaded = try store.load()!
            let restored = try loaded.restore(inventory: files, folderIdentity: identity).session
            try expect(!restored.files.contains(where: { $0.id == files[0].id }) && restored.staged.isEmpty && !restored.canUndo, "Transferred entry restored")
        }
    }
}
