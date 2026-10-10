import Foundation
import UnpileCore

struct LargeInventoryChecks {
    static func thousandFilesKeepBoundedSession() throws {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("UnpileLargeFixture-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("Synthetic inventory fixture".utf8)
        for index in 0..<1_000 {
            try data.write(to: root.appendingPathComponent(String(format: "fixture-%04d.txt", index)))
        }
        let inventory = try FileInventory.scan(folder: root, includeRecent: true).files
        try expect(inventory.count == 1_000, "Large inventory incomplete")
        var session = ReviewSession(files: FileOrder.name.sorted(inventory), limit: 100)
        for _ in 0..<100 { session.decide(.keep) }
        let identity = FileInventory.folderFingerprint(root)!
        let state = try ReviewState(folderIdentity: identity, preferences: ReviewPreferences(limit: 100), session: session, kept: [])
        let restored = try state.restore(inventory: FileInventory.scan(folder: root, includeRecent: true).files, folderIdentity: identity)
        try expect(restored.session.isComplete && restored.kept.count == 100 && restored.session.files.count == 100, "Session boundary failed")
        try expect(ReviewState.pending(inventory: inventory, kept: restored.kept).count == 900, "Large Keep reconciliation failed")
        try expect(try Data(contentsOf: root.appendingPathComponent("fixture-0000.txt")) == data, "Review changed fixture")
    }
}
