import Foundation
import UnpileCore

struct InventoryChecks {
    static func inventoryExcludesUnsafeEntries() throws {
        // Only this UUID-named synthetic fixture directory is created and removed.
        let fixture = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("UnpileTest-\(UUID())")
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let old = Date().addingTimeInterval(-200_000)
        for name in ["eligible.txt", ".hidden.txt", "incomplete.crdownload", "recent.txt"] {
            let url = fixture.appendingPathComponent(name)
            try Data("Synthetic".utf8).write(to: url)
            if name != "recent.txt" { try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: url.path) }
        }
        try FileManager.default.createDirectory(at: fixture.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: fixture.appendingPathComponent("link.txt"), withDestinationURL: fixture.appendingPathComponent("eligible.txt"))
        let result = try FileInventory.scan(folder: fixture)
        try expect(result.files.map(\.name) == ["eligible.txt"] && result.excludedCount == 5, "Unsafe entry entered queue")
        let recent = try FileInventory.scan(folder: fixture, includeRecent: true)
        try expect(Set(recent.files.map(\.name)) == ["eligible.txt", "recent.txt"], "Recent file option failed")
    }
    static func protectedRootsAreRejected() throws {
        for url in [FileManager.default.homeDirectoryForCurrentUser, URL(fileURLWithPath: "/"), URL(fileURLWithPath: "/Library")] {
            do { try FileInventory.validateFolder(url) }
            catch InventoryError.protectedFolder { continue }
            throw CheckFailure("Protected root accepted or returned an unexpected error")
        }
    }
}
