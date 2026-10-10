import Foundation

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw CheckFailure(message) }
}

@main
struct RunChecks {
    static func main() {
        let checks: [(String, () throws -> Void)] = [
            ("staging and undo preserve the source", SessionChecks.stagingIsReadOnly),
            ("deferred files do not loop", SessionChecks.laterDoesNotLoop),
            ("candidate exclusion can be undone", SessionChecks.candidateRemovalIsUndoable),
            ("session and queue limits", SessionChecks.sessionHasBoundedSize),
            ("sort order and active preview policy", SessionChecks.orderingAndPreviewPolicy),
            ("inventory excludes unsafe and recent entries", InventoryChecks.inventoryExcludesUnsafeEntries),
            ("protected roots are rejected", InventoryChecks.protectedRootsAreRejected),
            ("journal precedes transfers and partial failures stay distinct", TransferChecks.journalPrecedesOperationsAndPartialFailuresRemainDistinct),
            ("changed files and links never reach transfer driver", TransferChecks.changedFilesAndLinksNeverReachDriver),
            ("journal failure prevents transfer", TransferChecks.failedJournalWritePreventsAnyOperation),
            ("unresolved transfers are never repeated", TransferChecks.unresolvedJournalBlocksAutomaticRepeat),
            ("transferred files cannot return to undo or queue", TransferChecks.transferredFilesDoNotReturnToQueueOrUndo),
            ("decisions, queue, preferences and undo survive restart", PersistenceChecks.resumeDecisionsAndUndo),
            ("keep persists across batches and later returns", PersistenceChecks.keepPersistsWhileLaterReturns),
            ("changed versions and different folders lose stale intent", PersistenceChecks.changedVersionsNeverInheritIntent),
            ("invalid saved state is rejected without overwriting", PersistenceChecks.invalidStateNeverCreatesOperationURLs),
            ("private state and failed writes preserve sources", PersistenceChecks.privateStorageAndFailurePreserveSource),
            ("transferred entries cannot return from saved state", PersistenceChecks.transferredEntriesCannotReappearFromSnapshot),
            ("localization catalogs and placeholders match", LocalizationChecks.completeCatalogsAndMatchingPlaceholders),
            ("language selection and existing messages update", LocalizationChecks.languageSelectionAndStoredMessages),
            ("localized plurals, numbers, dates and sizes", LocalizationChecks.numbersDatesSizesAndPluralForms),
            ("1000 files retain a bounded, resumable session", LargeInventoryChecks.thousandFilesKeepBoundedSession),
            ("swipes decide after release with either scroll preference", SwipeChecks.releaseAndDirection),
            ("vertical scrolling and incomplete gestures do not decide", SwipeChecks.scrollingAndIncompleteSequences),
            ("cancelled, reversed and short swipes do not decide", SwipeChecks.cancellationAndReversal),
            ("one swipe cannot decide another card through momentum", SwipeChecks.oneDecisionAndMomentum),
            ("invalid and coarse swipe input never commits", SwipeChecks.invalidInputNeverCommits)
        ]
        var failures = 0
        for (name, check) in checks {
            do { try check(); print("PASS: \(name)") }
            catch { failures += 1; print("FAIL: \(name)") }
        }
        print("\(checks.count - failures)/\(checks.count) checks passed")
        if failures > 0 { exit(1) }
    }
}
