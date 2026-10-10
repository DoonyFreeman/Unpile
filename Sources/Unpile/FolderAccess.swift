import AppKit
import UnpileCore

@MainActor
final class FolderAccess {
    private var scopedURL: URL?
    private var started = false
    private let bookmarkURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        bookmarkURL = support.appendingPathComponent("Unpile", isDirectory: true).appendingPathComponent("folder.bookmark")
    }

    func select(_ url: URL) throws {
        try FileInventory.validateFolder(url)
        let didStart = url.startAccessingSecurityScopedResource()
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope],
                includingResourceValuesForKeys: nil, relativeTo: nil)
            try FileManager.default.createDirectory(at: bookmarkURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try data.write(to: bookmarkURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: bookmarkURL.path)
        } catch {
            if didStart { url.stopAccessingSecurityScopedResource() }
            throw error
        }
        release()
        scopedURL = url
        started = didStart
    }

    func restore() throws -> URL? {
        guard FileManager.default.fileExists(atPath: bookmarkURL.path) else { return nil }
        let data = try Data(contentsOf: bookmarkURL)
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
            relativeTo: nil, bookmarkDataIsStale: &stale)
        let didStart = url.startAccessingSecurityScopedResource()
        do {
            try FileInventory.validateFolder(url)
            guard FileManager.default.isReadableFile(atPath: url.path) else { throw InventoryError.cannotRead }
            if stale {
                let refreshed = try url.bookmarkData(options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil, relativeTo: nil)
                try refreshed.write(to: bookmarkURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: bookmarkURL.path)
            }
        } catch {
            if didStart { url.stopAccessingSecurityScopedResource() }
            throw error
        }
        release()
        scopedURL = url
        started = didStart
        return url
    }

    func release() {
        if started { scopedURL?.stopAccessingSecurityScopedResource() }
        scopedURL = nil
        started = false
    }

    func forget() throws {
        if FileManager.default.fileExists(atPath: bookmarkURL.path) { try FileManager.default.removeItem(at: bookmarkURL) }
        release()
    }
}
