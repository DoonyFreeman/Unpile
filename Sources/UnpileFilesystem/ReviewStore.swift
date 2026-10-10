import Foundation
import Darwin
import UnpileCore

public struct ReviewStore: Sendable {
    public let url: URL
    private let maximumBytes = 10_000_000
    public init(url: URL) { self.url = url }

    public func load() throws -> ReviewState? {
        try clearTemporaryFiles()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw ReviewStateError.tooLarge }
        let state = try JSONDecoder().decode(ReviewState.self, from: data)
        try state.validate()
        return state
    }

    public func save(_ state: ReviewState) throws {
        try state.validate()
        let data = try JSONEncoder().encode(state)
        guard data.count <= maximumBytes else { throw ReviewStateError.tooLarge }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        // Complete every fallible write step before replacing the accepted state.
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".review-\(UUID()).tmp")
        let descriptor = temporary.withUnsafeFileSystemRepresentation { path in
            path.map { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600)) } ?? -1
        }
        guard descriptor >= 0 else { throw ReviewStoreError.cannotWrite }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporary)
        }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()
        let replaced = temporary.withUnsafeFileSystemRepresentation { source in
            url.withUnsafeFileSystemRepresentation { destination in
                guard let source, let destination else { return false }
                return Darwin.rename(source, destination) == 0
            }
        }
        guard replaced else { throw ReviewStoreError.cannotWrite }
    }

    public func clear() throws {
        try clearTemporaryFiles()
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    // AppModel serializes this store. Only our UUID-named write fragments are removed.
    private func clearTemporaryFiles() throws {
        let parent = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parent.path) else { return }
        let children = try FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)
        for child in children {
            let name = child.lastPathComponent
            guard name.hasPrefix(".review-"), name.hasSuffix(".tmp"),
                  UUID(uuidString: String(name.dropFirst(8).dropLast(4))) != nil else { continue }
            // unlink never recursively deletes a directory or follows a symbolic link.
            let removed = child.withUnsafeFileSystemRepresentation { path in
                path.map { Darwin.unlink($0) == 0 || errno == ENOENT } ?? false
            }
            guard removed else { throw ReviewStoreError.cannotWrite }
        }
    }
}

private enum ReviewStoreError: Error { case cannotWrite }
