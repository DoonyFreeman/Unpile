import Foundation
import UniformTypeIdentifiers
import Darwin

public struct InventoryResult: Sendable {
    public let files: [FileRecord]
    public let excludedCount: Int
}

public struct FileFingerprint: Codable, Hashable, Sendable {
    public let device: UInt64
    public let inode: UInt64
    public let size: Int64
    public let seconds: Int64
    public let nanoseconds: Int64
}

public struct FolderFingerprint: Codable, Hashable, Sendable {
    public let device: UInt64
    public let inode: UInt64
}

public enum InventoryError: LocalizedError, Equatable {
    case invalidFolder, protectedFolder, unsupportedVolume, cannotRead
    public var errorDescription: String? {
        switch self {
        case .invalidFolder: "Выберите обычную папку. Ссылки и пакеты не поддерживаются."
        case .protectedFolder: "Выберите папку с загрузками, а не домашний или системный каталог."
        case .unsupportedVolume: "На этом этапе поддерживаются только локальные папки."
        case .cannotRead: "Не удалось прочитать папку. Выберите её снова."
        }
    }
}

public enum FileInventory {
    private static let home = getpwuid(getuid()).map {
        URL(fileURLWithPath: String(cString: $0.pointee.pw_dir)).standardizedFileURL
    }
    public static func fingerprint(_ url: URL) -> FileFingerprint? {
        var info = stat()
        guard url.withUnsafeFileSystemRepresentation({ path in path.map { lstat($0, &info) } ?? -1 }) == 0,
              info.st_mode & S_IFMT == S_IFREG else { return nil }
        return FileFingerprint(device: UInt64(UInt32(bitPattern: info.st_dev)), inode: UInt64(info.st_ino), size: info.st_size,
            seconds: Int64(info.st_mtimespec.tv_sec), nanoseconds: Int64(info.st_mtimespec.tv_nsec))
    }
    public static func folderFingerprint(_ url: URL) -> FolderFingerprint? {
        var info = stat()
        guard url.withUnsafeFileSystemRepresentation({ path in path.map { lstat($0, &info) } ?? -1 }) == 0,
              info.st_mode & S_IFMT == S_IFDIR else { return nil }
        return FolderFingerprint(device: UInt64(UInt32(bitPattern: info.st_dev)), inode: UInt64(info.st_ino))
    }
    public static func isUnchanged(_ file: FileRecord) -> Bool {
        guard let url = file.url, let original = file.fingerprint else { return false }
        return fingerprint(url) == original
    }
    public static func validateFolder(_ folder: URL) throws {
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .volumeIsLocalKey])
        guard values.isDirectory == true, values.isSymbolicLink != true, values.isPackage != true else { throw InventoryError.invalidFolder }
        guard values.volumeIsLocal == true else { throw InventoryError.unsupportedVolume }
        let resolved = folder.resolvingSymlinksInPath().standardizedFileURL
        let path = resolved.path
        let protected = ["/System", "/Library", "/Applications", "/private", "/usr", "/bin", "/sbin", "/dev", "/Volumes"]
        let parts = resolved.pathComponents
        if path == "/" || resolved == home || path == "/Users" ||
            protected.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) ||
            parts.contains(".Trash") || parts.contains(".Trashes") ||
            parts.contains("Library") {
            throw InventoryError.protectedFolder
        }
    }

    public static func scan(folder: URL, includeRecent: Bool = false, now: Date = Date()) throws -> InventoryResult {
        try validateFolder(folder)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .isAliasFileKey, .isPackageKey,
            .isHiddenKey, .isUbiquitousItemKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey, .fileResourceIdentifierKey]
        let urls: [URL]
        do { urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) }
        catch { throw InventoryError.cannotRead }
        var records: [FileRecord] = []
        var excluded = 0
        for url in urls {
            try Task.checkCancellation()
            // lstat first: do not request target metadata for symbolic links.
            guard let fingerprint = fingerprint(url), let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true, values.isSymbolicLink != true, values.isAliasFile != true,
                  values.isHidden != true, values.isPackage != true, values.isUbiquitousItem != true,
                  !["part", "crdownload", "download", "tmp"].contains(url.pathExtension.lowercased()),
                  let modified = values.contentModificationDate, let size = values.fileSize,
                  includeRecent || modified <= now.addingTimeInterval(-86_400),
                  self.fingerprint(url) == fingerprint else {
                excluded += 1
                continue
            }
            records.append(FileRecord(name: url.lastPathComponent, url: url, size: Int64(size), modified: modified,
                typeIdentifier: values.contentType?.identifier,
                resourceIdentifier: values.fileResourceIdentifier.map { String(describing: $0) }, fingerprint: fingerprint))
        }
        return InventoryResult(files: records, excludedCount: excluded)
    }
}
