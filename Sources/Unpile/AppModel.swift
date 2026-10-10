import AppKit
import SwiftUI
import UnpileCore
import UnpileFilesystem

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var session = ReviewSession(files: [])
    @Published private(set) var folder: URL?
    @Published private(set) var isDemo = false
    @Published private(set) var isLoading = false
    @Published private(set) var excludedCount = 0
    @Published private(set) var totalCount = 0
    @Published var order: FileOrder = .largest
    @Published var includeRecent = false
    @Published var sessionLimit = 20
    @Published var isSettingsPresented = false
    @Published private(set) var rememberedCount = 0
    @Published private(set) var persistenceProblem: LocalizedMessage?
    @Published var language: AppLanguage = .system {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "interfaceLanguage") }
    }
    @Published var previewFile: FileRecord?
    @Published private(set) var isChoosingFolder = false
    @Published private(set) var isConfirming = false
    @Published var isReviewing = false
    @Published var error: LocalizedMessage?
    @Published private(set) var isExecuting = false
    @Published private(set) var transferProgress = 0
    @Published private(set) var transferTotal = 0
    @Published private(set) var transferReport: TransferReport?
    @Published private(set) var recoveryRequired = false
    @Published private(set) var recoveryEntries: [JournalEntry] = []
    @Published var status: LocalizedMessage = "Файлы не изменяются"
    private let access = FolderAccess()
    private var inventory: [FileRecord] = []
    private var scanTask: Task<Void, Never>?
    private var scanGeneration = UUID()
    private var folderIdentity: FolderFingerprint?
    private var executionTask: Task<Void, Never>?
    private var executionGeneration = UUID()
    private let journalStore: JournalStore
    private let reviewStore: ReviewStore
    private var savedState: ReviewState?
    private var keptVersions: [SavedFileVersion] = []
    private var scanFailed = false
    private var unreadableState = false
    private var restoredTransferIDs: Set<UUID> = []
    private enum ScanIntent { case resume, next, reconsider }

    var hasSession: Bool { isDemo || folder != nil }
    var text: Localizer { Localizer(language: language) }
    var folderName: String { isDemo ? text("Downloads · демо") : folder?.lastPathComponent ?? "Downloads" }
    private var hasOverlay: Bool { isReviewing || isSettingsPresented || previewFile != nil || isChoosingFolder || isConfirming || error != nil }
    var canDecide: Bool { !isLoading && !scanFailed && !hasOverlay && !isExecuting && !recoveryRequired && (isDemo || persistenceProblem == nil) }
    var canSwitchFolder: Bool { !isExecuting && !recoveryRequired && !hasOverlay }
    var canChangePreferences: Bool { !isLoading && !scanFailed && !isExecuting && !recoveryRequired && session.reviewedCount == 0 && (isDemo || persistenceProblem == nil) }
    var canRetrySaving: Bool { folder != nil && !unreadableState && !scanFailed && !isLoading && !isExecuting && !recoveryRequired }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        journalStore = JournalStore(url: support.appendingPathComponent("Unpile/trash-journal.json"))
        reviewStore = ReviewStore(url: support.appendingPathComponent("Unpile/review-state.json"))
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "system") ?? .system
        do {
            savedState = try reviewStore.load()
            keptVersions = savedState?.kept ?? []
            if let preferences = savedState?.preferences {
                order = preferences.order; includeRecent = preferences.includeRecent; sessionLimit = preferences.limit
            }
        } catch {
            unreadableState = true
            persistenceProblem = "Сохранённый разбор не удалось прочитать. Сбросьте локальные решения в настройках, чтобы продолжить."
        }
        do {
            if let journal = try journalStore.load() {
                restoredTransferIDs = Set(journal.entries.filter { $0.state == .trashed }.map(\.id))
                if journal.requiresRecovery {
                    recoveryRequired = true; recoveryEntries = journal.entries; isReviewing = true
                } else { try journalStore.clear() }
            }
        } catch {
            recoveryRequired = true; isReviewing = true
            self.error = "Не удалось проверить журнал предыдущего переноса. Новые операции заблокированы до проверки Корзины."
        }
        do {
            if let url = try access.restore() { folder = url; folderIdentity = FileInventory.folderFingerprint(url); refresh() }
        } catch { self.error = "Не удалось восстановить доступ. Выберите папку снова." }
    }

    func chooseFolder() {
        guard canSwitchFolder else { return }
        guard persistenceProblem == nil else { isSettingsPresented = true; return }
        let panel = NSOpenPanel()
        panel.title = text("Выберите папку для разбора")
        panel.prompt = text("Выбрать папку")
        panel.message = text("Разрешите доступ к выбранной папке. Файлы будут перемещаться в Корзину только после отдельного подтверждения списка.")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.directoryURL = folder
        isChoosingFolder = true
        let response = panel.runModal()
        isChoosingFolder = false
        guard response == .OK, let url = panel.url else { return }
        let previous = savedState
        do {
            try FileInventory.validateFolder(url)
            let identity = FileInventory.folderFingerprint(url)
            let different = savedState != nil && savedState?.folderIdentity != identity
            if different {
                guard confirmForget() else { return }
                try reviewStore.clear()
            }
            try access.select(url)
            if different { savedState = nil; keptVersions = []; rememberedCount = 0 }
            folder = url
            folderIdentity = identity
            isDemo = false
            refresh()
        } catch {
            if let previous { try? reviewStore.save(previous) }
            self.error = LocalizedMessage((error as? InventoryError)?.localizedDescription ?? "Не удалось сохранить доступ к папке. Попробуйте выбрать её снова.")
        }
    }

    func showDemo() {
        guard canSwitchFolder else { return }
        scanTask?.cancel()
        scanGeneration = UUID()
        access.release()
        folder = nil
        folderIdentity = nil
        isDemo = true
        isLoading = false
        scanFailed = false
        inventory = DemoData.files
        excludedCount = 0
        totalCount = inventory.count
        session = ReviewSession(files: order.sorted(inventory), limit: sessionLimit)
        rememberedCount = 0
        status = "Вымышленные файлы · решения не сохраняются"
        transferReport = nil
    }

    func beginAgain() {
        guard !isExecuting, !recoveryRequired, !isLoading else { return }
        guard isDemo || persistenceProblem == nil else { isSettingsPresented = true; return }
        guard confirmDiscardCandidates() else { return }
        if isDemo { session = ReviewSession(files: order.sorted(inventory), limit: sessionLimit) }
        else { scan(intent: .next) }
    }

    func reconsiderKept() {
        guard !isDemo, !isExecuting, !recoveryRequired, persistenceProblem == nil else { return }
        guard confirmDiscardCandidates() else { return }
        isSettingsPresented = false
        scan(intent: .reconsider)
    }

    func changePreferences() {
        guard canChangePreferences || isLoading else { return }
        if isDemo { session = ReviewSession(files: order.sorted(inventory), limit: sessionLimit) }
        else { scan(intent: .next) }
    }

    func refresh() { scan(intent: .resume) }

    private func scan(intent: ScanIntent) {
        guard let folder, !isExecuting else { return }
        scanTask?.cancel()
        let generation = UUID()
        scanGeneration = generation
        let includeRecent = self.includeRecent
        isLoading = true
        status = "Читаем список файлов…"
        scanTask = Task {
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try FileInventory.scan(folder: folder, includeRecent: includeRecent)
                }
                let result = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled, self.scanGeneration == generation else { return }
                guard let identity = FileInventory.folderFingerprint(folder), identity == self.folderIdentity else { throw ReviewStateError.differentFolder }
                self.inventory = result.files
                self.excludedCount = result.excludedCount
                self.totalCount = result.files.count
                self.isLoading = false
                self.applyInventory(identity: identity, intent: intent)
            } catch {
                guard !Task.isCancelled, self.scanGeneration == generation else { return }
                self.isLoading = false
                self.scanFailed = true
                self.inventory = []
                self.session = ReviewSession(files: [])
                self.totalCount = 0
                self.error = LocalizedMessage((error as? InventoryError)?.localizedDescription ?? "Не удалось прочитать папку. Выберите её снова.")
            }
        }
    }

    private func applyInventory(identity: FolderFingerprint, intent: ScanIntent) {
        var kept: [SavedFileVersion] = []
        var next: ReviewSession
        var invalidated = 0
        do {
            if let savedState {
                let restored = try savedState.restore(inventory: inventory, folderIdentity: identity)
                kept = intent == .reconsider ? [] : restored.kept
                invalidated = restored.invalidatedCount
                if intent == .resume { next = restored.session }
                else { next = ReviewSession(files: order.sorted(ReviewState.pending(inventory: inventory, kept: kept)), limit: sessionLimit) }
            } else { next = ReviewSession(files: order.sorted(inventory), limit: sessionLimit) }
            if !restoredTransferIDs.isEmpty { next.finishTransfer(restoredTransferIDs); restoredTransferIDs = [] }
            session = next
            scanFailed = false
            keptVersions = kept
            rememberedCount = kept.count
            if unreadableState { return }
            do {
                let state = try ReviewState(folderIdentity: identity, preferences: preferences, session: next, kept: kept)
                try reviewStore.save(state)
                savedState = state
                keptVersions = state.kept
                rememberedCount = state.kept.count
                persistenceProblem = nil
            } catch {
                persistenceProblem = "Не удалось сохранить разбор. Перенос заблокирован; повторите запись в настройках."
            }
            status = persistenceProblem != nil ? "Не удалось сохранить разбор" : intent == .resume && next.reviewedCount > 0 ? "Разбор восстановлен · решения сохранены" : "Решения сохраняются на этом Mac"
            if invalidated > 0 { status = LocalizedMessage("Разбор обновлён · сброшено устаревших решений: %lld", invalidated) }
        } catch {
            unreadableState = true
            persistenceProblem = "Не удалось восстановить или сохранить разбор. Перенос заблокирован до проверки локального состояния в настройках."
            session = ReviewSession(files: order.sorted(inventory), limit: sessionLimit)
        }
        transferReport = nil
    }

    private var preferences: ReviewPreferences { ReviewPreferences(order: order, includeRecent: includeRecent, limit: sessionLimit) }

    @discardableResult private func commit(_ next: ReviewSession) -> Bool {
        if isDemo { session = next; return true }
        guard let identity = folderIdentity, !unreadableState else { return false }
        do {
            let state = try ReviewState(folderIdentity: identity, preferences: preferences, session: next, kept: keptVersions)
            try reviewStore.save(state)
            savedState = state; keptVersions = state.kept; session = next; rememberedCount = state.kept.count; persistenceProblem = nil
            return true
        } catch {
            persistenceProblem = "Не удалось сохранить решения. Перенос заблокирован; повторите запись в настройках."
            self.error = persistenceProblem
            return false
        }
    }

    func retrySaving() {
        guard canRetrySaving else { return }
        if commit(session) { status = "Решения сохранены на этом Mac" }
    }

    func forgetReview() {
        guard !isExecuting, !recoveryRequired else { return }
        let alert = NSAlert()
        alert.messageText = text("Сбросить сохранённый разбор?")
        alert.informativeText = text("Очередь, кандидаты и память об оставленных файлах будут очищены. Сами файлы останутся на месте.")
        alert.addButton(withTitle: text("Отмена")); alert.addButton(withTitle: text("Сбросить решения"))
        guard runAlert(alert) == .alertSecondButtonReturn else { return }
        do {
            try reviewStore.clear(); savedState = nil; keptVersions = []; unreadableState = false; persistenceProblem = nil; rememberedCount = 0
            isSettingsPresented = false
            if isDemo { session = ReviewSession(files: order.sorted(inventory), limit: sessionLimit) }
            else { scan(intent: .next) }
        } catch { self.error = "Не удалось сбросить локальные решения. Файлы не изменены." }
    }

    func decide(_ decision: Decision, for fileID: UUID) {
        guard session.current?.id == fileID else { return }
        decide(decision)
    }
    func decide(_ decision: Decision) {
        guard canDecide, session.current != nil else { return }
        var next = session; next.decide(decision)
        guard commit(next) else { return }
        status = switch decision {
        case .keep: "Оставлено на месте"
        case .stage: "Добавлено к проверке · файл остаётся на месте"
        case .later: "Отложено до следующего разбора"
        }
    }
    func undo() {
        guard canDecide, session.canUndo else { return }
        var next = session; next.undo()
        if commit(next) { status = isDemo ? "Последнее решение отменено · демо" : "Последнее решение отменено · сохранено" }
    }
    func keepCandidate(_ id: UUID) {
        guard !isExecuting, !recoveryRequired, isDemo || persistenceProblem == nil else { return }
        var next = session; next.keepCandidate(id)
        if commit(next) { status = isDemo ? "Исключено из кандидатов · демо" : "Исключено из кандидатов · сохранено" }
    }
    func review() {
        guard !isLoading, !isExecuting, !isSettingsPresented, previewFile == nil, !isChoosingFolder, !isConfirming, error == nil else { return }
        if !recoveryRequired { transferReport = nil }
        isReviewing = true
    }
    func disconnect() {
        guard canSwitchFolder else { return }
        guard confirmForget() else { return }
        let previous = savedState
        do { try reviewStore.clear(); try access.forget() }
        catch {
            if let previous { try? reviewStore.save(previous) }
            self.error = "Не удалось удалить сохранённый доступ. Папка не изменена."; return
        }
        savedState = nil; keptVersions = []; unreadableState = false; persistenceProblem = nil; rememberedCount = 0
        scanTask?.cancel()
        scanGeneration = UUID()
        folder = nil
        folderIdentity = nil
        isDemo = false
        isLoading = false
        scanFailed = false
        inventory = []
        session = ReviewSession(files: [])
        totalCount = 0
    }

    var canTransfer: Bool { !isDemo && folder != nil && folderIdentity != nil && !session.staged.isEmpty && !isLoading && !scanFailed && !isExecuting && !recoveryRequired && persistenceProblem == nil && previewFile == nil && !isSettingsPresented && !isChoosingFolder && !isConfirming && error == nil }

    func preview(_ file: FileRecord) {
        guard canDecide, session.current?.id == file.id, file.supportsPreview else { return }
        guard isDemo || FileInventory.isUnchanged(file) else {
            error = "Файл изменился. Начните новый разбор, чтобы обновить превью."; return
        }
        previewFile = file
    }

    func transferApprovedCandidates() {
        guard canTransfer, let root = folder, let identity = folderIdentity else { return }
        let files = session.staged
        isExecuting = true
        transferProgress = 0; transferTotal = files.count; transferReport = nil
        let generation = UUID()
        executionGeneration = generation
        let store = journalStore
        executionTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                try TrashExecutor(driver: SystemTrashDriver(), journalStore: store).execute(files: files, root: root, rootIdentity: identity) { done, total in
                    Task { @MainActor [weak self] in
                        guard let self, self.executionGeneration == generation, self.isExecuting else { return }
                        self.transferProgress = done; self.transferTotal = total
                    }
                }
            }
            do {
                let report = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                for entry in report.entries where entry.state == .changed { self.session.keepCandidate(entry.id) }
                self.session.finishTransfer(report.successfulIDs)
                self.transferReport = report
                self.recoveryRequired = report.needsRecovery
                if report.needsRecovery { self.recoveryEntries = report.entries }
                self.status = LocalizedMessage("В Корзине: %lld. Остальные файлы не считаются перемещёнными.", report.successfulIDs.count)
            } catch {
                self.error = "Перенос остановлен. Проверьте Корзину и исходную папку перед новой операцией."
                do {
                    if let journal = try store.load() {
                        self.recoveryEntries = journal.entries; self.recoveryRequired = journal.requiresRecovery
                        self.session.finishTransfer(Set(journal.entries.filter { $0.state == .trashed }.map(\.id)))
                    }
                } catch { self.recoveryRequired = true }
            }
            self.isExecuting = false
            self.executionTask = nil
            if !self.isDemo { _ = self.commit(self.session) }
        }
    }

    func stopTransfer() { executionTask?.cancel() }
    func acknowledgeRecovery() {
        guard !isExecuting else { return }
        do { try journalStore.clear(); recoveryRequired = false; recoveryEntries = []; transferReport = nil }
        catch { self.error = "Не удалось сбросить локальный журнал. Новые операции остаются заблокированными." }
    }

    private func confirmDiscardCandidates() -> Bool {
        guard !session.staged.isEmpty else { return true }
        let alert = NSAlert()
        alert.messageText = text("Сбросить непроверенных кандидатов?")
        alert.informativeText = text("Кандидаты текущего разбора будут сброшены. Сначала можно вернуться и проверить список. Файлы не перемещаются.")
        alert.addButton(withTitle: text("Продолжить текущий"))
        alert.addButton(withTitle: text("Начать новый"))
        return runAlert(alert) == .alertSecondButtonReturn
    }

    private func confirmForget() -> Bool {
        guard unreadableState || !(savedState?.kept.isEmpty ?? true) || !(savedState?.decisions.isEmpty ?? true) else { return true }
        let alert = NSAlert()
        alert.messageText = text("Очистить память о текущей папке?")
        alert.informativeText = text("Сохранённые решения и кандидаты будут удалены с этого Mac. Файлы останутся на месте.")
        alert.addButton(withTitle: text("Отмена")); alert.addButton(withTitle: text("Продолжить"))
        return runAlert(alert) == .alertSecondButtonReturn
    }

    private func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        isConfirming = true
        defer { isConfirming = false }
        return alert.runModal()
    }
}

enum DemoData {
    static var files: [FileRecord] {
        let date = Date().addingTimeInterval(-30 * 86_400)
        return [
            FileRecord(name: "Mountain-weekend.mov", size: 1_820_000_000, modified: date, typeIdentifier: "com.apple.quicktime-movie"),
            FileRecord(name: "StudioSetup-4.0.dmg", size: 720_000_000, modified: date.addingTimeInterval(-86_400)),
            FileRecord(name: "Design-assets-old.zip", size: 86_000_000, modified: date, typeIdentifier: "public.zip-archive"),
            FileRecord(name: "Mountain-weekend.heic", size: 42_000_000, modified: date, typeIdentifier: "public.heic"),
            FileRecord(name: "Workshop-notes.pdf", size: 12_000_000, modified: date, typeIdentifier: "com.adobe.pdf"),
            FileRecord(name: "Book-list.pdf", size: 4_000_000, modified: date, typeIdentifier: "com.adobe.pdf"),
            FileRecord(name: "Ideas-draft.txt", size: 1_200_000, modified: date, typeIdentifier: "public.plain-text"),
            FileRecord(name: "sample-data.csv", size: 600_000, modified: date, typeIdentifier: "public.comma-separated-values-text")
        ]
    }
}
