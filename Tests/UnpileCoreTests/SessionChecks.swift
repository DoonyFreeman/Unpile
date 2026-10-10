import Foundation
import UnpileCore

struct SessionChecks {
    static func file(_ name: String, size: Int64 = 10, age: TimeInterval = 100) -> FileRecord {
        FileRecord(name: name, size: size, modified: Date(timeIntervalSince1970: age))
    }
    static func stagingIsReadOnly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fixture.txt")
        let data = Data("Synthetic fixture".utf8)
        try data.write(to: url)
        let record = FileRecord(name: url.lastPathComponent, url: url, size: Int64(data.count), modified: .now)
        var session = ReviewSession(files: [record])
        session.decide(.stage)
        try expect(session.staged.map(\.id) == [record.id], "Candidate missing")
        try expect(Data(contentsOf: url) == data, "Staging changed the source")
        session.undo()
        try expect(session.current?.id == record.id && session.staged.isEmpty, "Undo failed")
        try expect(Data(contentsOf: url) == data, "Undo changed the source")
    }
    static func laterDoesNotLoop() throws {
        var session = ReviewSession(files: [file("one"), file("two")])
        session.decide(.later)
        session.decide(.keep)
        try expect(session.isComplete && session.reviewedCount == 2, "Deferred file looped back")
    }
    static func candidateRemovalIsUndoable() throws {
        let record = file("one", size: 123)
        var session = ReviewSession(files: [record])
        session.decide(.stage)
        session.keepCandidate(record.id)
        try expect(session.stagedBytes == 0, "Candidate not excluded")
        session.undo()
        try expect(session.stagedBytes == 123, "Exclusion undo failed")
    }
    static func sessionHasBoundedSize() throws {
        let session = ReviewSession(files: (0..<30).map { file("file-\($0)") }, limit: 20)
        try expect(session.files.count == 20 && session.upcoming.count == 4, "Session bound failed")
        try expect(ReviewSession(files: [file("one")], limit: 0).isComplete, "Empty limit failed")
    }
    static func orderingAndPreviewPolicy() throws {
        let files = [file("small", size: 1, age: 20), file("large", size: 100, age: 10)]
        try expect(FileOrder.largest.sorted(files).first?.name == "large", "Size order failed")
        try expect(FileOrder.oldest.sorted(files).first?.name == "large", "Age order failed")
        try expect(!file("active.svg").supportsPreview && !file("active.html").supportsPreview, "Active document allowed")
        try expect(file("document.pdf").supportsPreview, "PDF preview excluded")
    }
}
