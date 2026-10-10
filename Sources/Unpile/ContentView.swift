import SwiftUI
import AppKit
import UnpileCore
import UnpileFilesystem

struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.hasSession {
                folderBar
                ProgressView(value: Double(model.session.reviewedCount), total: Double(max(1, model.session.files.count)))
                    .tint(.blue).padding(.horizontal, 28)
                    .accessibilityLabel(model.text("Прогресс разбора"))
                    .accessibilityValue(model.text("Просмотрено %@ из %@", model.text.number(model.session.reviewedCount), model.text.number(model.session.files.count)))
                GeometryReader { geometry in
                    ScrollView {
                        if model.isLoading {
                            ProgressView(model.text("Читаем список файлов…")).frame(maxWidth: .infinity).padding(80)
                        } else if let current = model.session.current {
                            reviewBody(current, showsQueue: geometry.size.width > 850)
                        } else {
                            emptyState
                        }
                    }
                }
                if model.session.current != nil && !model.isLoading { decisionDock }
                footer
            } else {
                welcome
            }
        }
        .background(background)
        .sheet(isPresented: $model.isReviewing) { CandidateReview(model: model) }
        .sheet(isPresented: $model.isSettingsPresented) { ReviewSettings(model: model) }
        .sheet(item: $model.previewFile) { file in
            VStack(spacing: 18) {
                HStack {
                    Text(file.name).font(.headline).textSelection(.enabled)
                    Spacer()
                    Button(model.text("Закрыть")) { model.previewFile = nil }.keyboardShortcut(.cancelAction)
                }
                Group {
                    if file.url != nil { NativeFilePreview(file: file, text: model.text) }
                    else { FilePreview(file: file, text: model.text) }
                }.frame(height: 390).clipShape(RoundedRectangle(cornerRadius: 20))
                Text(model.text.size(file.size) + " · " + model.text.typeLabel(file)).foregroundStyle(.secondary)
            }.padding(24).frame(width: 720)
        }
        .alert(model.text("Не удалось выполнить действие"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(model.text("Понятно"), role: .cancel) { model.error = nil }
        } message: { Text(model.text.render(model.error ?? "Попробуйте снова.")) }
        .environment(\.locale, model.text.locale)
        .onChange(of: model.order) { _, _ in model.changePreferences() }
        .onChange(of: model.includeRecent) { _, _ in model.changePreferences() }
        .onChange(of: model.sessionLimit) { _, _ in model.changePreferences() }
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [.blue.opacity(0.09), .mint.opacity(0.05), .indigo.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.cyan.opacity(0.09), .clear], center: .topLeading, startRadius: 0, endRadius: 700)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            BrandIcon(size: 31)
            Text("Unpile").font(.system(size: 14, weight: .semibold))
            Spacer()
            Label(model.text("ЛОКАЛЬНАЯ BETA"), systemImage: "shield.lefthalf.filled")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            Button { model.isSettingsPresented = true } label: { Image(systemName: "gearshape") }
                .modifier(NativeButtonStyle()).accessibilityLabel(model.text("Настройки разбора"))
                .help(model.text("Настройки и сохранённые решения"))
                .disabled(!model.canSwitchFolder)
        }
        .padding(.leading, 82).padding(.trailing, 26).padding(.vertical, 13)
        .background(.bar)
    }

    private var folderBar: some View {
        HStack(spacing: 14) {
            Button { model.chooseFolder() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.minus").font(.title3).foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.folderName).font(.system(size: 14, weight: .semibold))
                        Text(model.text("%@ · сессия до %@", model.text.fileCount(model.totalCount), model.text.number(model.sessionLimit))).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }.padding(.vertical, 4)
            }
            .modifier(NativeButtonStyle())
            .help(model.text("Выбрать другую папку"))
            .disabled(model.isExecuting || model.recoveryRequired)
            Picker(model.text("Порядок"), selection: $model.order) {
                ForEach(FileOrder.allCases) { order in Text(model.text(order.title)).tag(order) }
            }
            .labelsHidden().frame(width: 160)
            .disabled(!model.canChangePreferences)
            Toggle(model.text("Недавние"), isOn: $model.includeRecent)
                .font(.system(size: 12)).toggleStyle(.checkbox)
                .disabled(model.isDemo || !model.canChangePreferences)
                .help(model.text("Включить файлы, изменённые за последние 24 часа"))
            Spacer(minLength: 6)
            Text(model.text("%@ из %@", model.text.number(model.session.reviewedCount), model.text.number(model.session.files.count)))
                .font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
            Button(model.text("Завершить")) { model.review() }
                .modifier(NativeButtonStyle()).disabled(model.isLoading)
        }.padding(.horizontal, 27).padding(.vertical, 13)
    }

    private func reviewBody(_ file: FileRecord, showsQueue: Bool) -> some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack {
                Text(model.text("Что оставим?")).font(.system(size: 27, weight: .semibold)).tracking(-0.6).accessibilityHeading(.h1)
                Spacer()
                Text(model.isDemo ? model.text("Демонстрация") : model.text("Короткая сессия"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .modifier(GlassSurface(radius: 20))
            }
            HStack(alignment: .top, spacing: 29) {
                VStack(spacing: 0) {
                    FileCard(file: file, text: model.text, enabled: model.canDecide,
                             preview: { model.preview(file) }, decide: { model.decide($0, for: file.id) })
                        .id(file.id)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: reduceMotion ? 0 : 14)),
                                                removal: .opacity))
                }.frame(maxWidth: 570)
                if showsQueue { queue.frame(width: 208) }
            }
            .frame(maxWidth: .infinity)
            if model.excludedCount > 0 {
                Text(model.text("Пропущено: %@. Папки, ссылки, скрытые и незавершённые файлы не входят в разбор.", model.text.number(model.excludedCount)))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 850)
        .padding(.horizontal, 30).padding(.top, 20).padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: model.session.current?.id)
    }

    private var decisionDock: some View {
        VStack(spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "hand.draw").accessibilityHidden(true)
                Text(model.text("Свайп двумя пальцами по карточке"))
                Text("·").accessibilityHidden(true)
                Text(model.text("← На удаление · Оставить →"))
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            GlassGroup {
                HStack(spacing: 12) {
                    decisionControl(.stage, title: "На удаление", icon: "trash", key: "←", color: .red)
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .help(model.text("На удаление — добавить к проверке, файл остаётся на месте"))
                        .accessibilityHint(model.text("На удаление — добавить к проверке, файл остаётся на месте"))
                    decisionControl(.later, title: "Позже", icon: "clock", key: "↓", color: .secondary)
                        .keyboardShortcut(.downArrow, modifiers: [])
                        .accessibilityHint(model.text("Позже — вернуть в следующем разборе"))
                    decisionControl(.keep, title: "Оставить", icon: "checkmark", key: "→", color: .mint)
                        .keyboardShortcut(.rightArrow, modifiers: [])
                        .accessibilityHint(model.text("Оставить — запомнить неизменившийся файл"))
                }.disabled(!model.canDecide)
            }.frame(maxWidth: 570)
        }.padding(.horizontal, 30).padding(.top, 8).padding(.bottom, 12)
    }

    private func decisionControl(_ decision: Decision, title: String, icon: String, key: String, color: Color) -> some View {
        Button { model.decide(decision) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 19, weight: .medium))
                    .foregroundStyle(color).frame(width: 36, height: 36)
                    .background(color.opacity(0.1), in: Circle()).accessibilityHidden(true)
                Text(model.text(title)).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.82)
                Spacer(minLength: 0)
                Text(key).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary).accessibilityHidden(true)
            }.padding(.horizontal, 13).padding(.vertical, 11).frame(maxWidth: .infinity)
        }
        .buttonStyle(DecisionControlStyle(accent: color))
        .accessibilityLabel(model.text(title))
    }

    private var queue: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.text("Следующие файлы")).font(.system(size: 12)).foregroundStyle(.secondary)
            ForEach(model.session.upcoming) { file in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: file.icon).foregroundStyle(.blue).frame(width: 30, height: 35)
                        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name).font(.system(size: 11)).lineLimit(3).help(file.name)
                        Text(model.text.size(file.size)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityLabel(model.text("Следующий файл: %@, %@", file.name, model.text.size(file.size)))
                if file.id != model.session.upcoming.last?.id { Divider() }
            }
            if model.session.upcoming.isEmpty { Text(model.text("Последняя карточка")).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(17).modifier(GlassSurface(radius: 23))
        .accessibilityElement(children: .contain)
    }

    private var footer: some View {
        HStack(spacing: 13) {
            Button { model.undo() } label: { Label(model.text("Отменить"), systemImage: "arrow.uturn.backward") }
                .modifier(NativeButtonStyle()).disabled(!model.session.canUndo || !model.canDecide)
            if model.persistenceProblem != nil && !model.isDemo {
                Button(model.text("Проверить сохранение")) { model.isSettingsPresented = true }
                    .foregroundStyle(.orange).modifier(NativeButtonStyle())
            } else { Text(model.text.render(model.status)).font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(2).accessibilityAddTraits(.updatesFrequently)
            }
            Spacer()
            Button { model.review() } label: {
                Text(model.text("Проверить · %@", model.text.number(model.session.staged.count)) + (model.session.staged.isEmpty ? "" : " · " + model.text.size(model.session.stagedBytes)))
            }
            .modifier(NativeButtonStyle(prominent: true)).keyboardShortcut(.return, modifiers: .command)
            .disabled(model.isLoading)
        }
        .padding(12).modifier(GlassSurface(radius: 22))
        .padding(.horizontal, 22).padding(.bottom, 14)
    }

    private var welcome: some View {
        VStack(spacing: 23) {
            Spacer()
            BrandIcon(size: 112)
                .shadow(color: .blue.opacity(0.18), radius: 20, y: 8)
            Text(model.text("Разберите Загрузки\nпо одному файлу"))
                .font(.system(size: 35, weight: .semibold)).tracking(-0.8).multilineTextAlignment(.center).accessibilityHeading(.h1)
            Text(model.text("Смотрите превью. Оставляйте нужное.\nПереносите лишнее в Корзину после проверки списка."))
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            GlassGroup {
                HStack(spacing: 14) {
                    Button { model.chooseFolder() } label: { Label(model.text("Выбрать папку…"), systemImage: "folder") }
                        .modifier(NativeButtonStyle(prominent: true))
                    Button(model.text("Попробовать демо")) { model.showDemo() }.modifier(NativeButtonStyle())
                }.controlSize(.large)
            }
            Label(model.text("Ничего не перемещается без вашего подтверждения"), systemImage: "lock.shield")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(model.text("Локально · без аккаунта · без передачи файлов"))
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 32)
        }.padding(.horizontal, 35).frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: model.session.files.isEmpty ? "folder" : "checkmark.circle")
                .font(.system(size: 45, weight: .light)).foregroundStyle(.blue)
            Text(model.session.files.isEmpty ? model.text("Здесь пока нечего разбирать") : model.text("Сессия разобрана"))
                .font(.system(size: 27, weight: .semibold))
                .accessibilityHeading(.h1)
            Text(model.session.files.isEmpty && model.rememberedCount > 0 ? model.text("Оставленные файлы запомнены. Начните следующий разбор или пересмотрите их.") : model.session.files.isEmpty ? model.text("Попробуйте включить недавние файлы или выбрать другую папку.") : model.isDemo ? model.text("Демонстрация завершена. Решения не сохраняются.") : model.text("Решения сохранены. Можно проверить выбранное или начать следующую сессию."))
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button(model.text("Выбрать папку…")) { model.chooseFolder() }.modifier(NativeButtonStyle())
                if !model.session.files.isEmpty {
                    Button(model.text("Проверить выбранное")) { model.review() }.modifier(NativeButtonStyle(prominent: true))
                }
                if model.totalCount > 0 { Button(model.text("Следующий разбор")) { model.beginAgain() }.modifier(NativeButtonStyle()) }
            }
            if model.rememberedCount > 0 {
                Button(model.text("Пересмотреть оставленные · %@", model.text.number(model.rememberedCount))) { model.reconsiderKept() }.modifier(NativeButtonStyle())
            }
            Button(model.text("Отключить папку")) { model.disconnect() }.buttonStyle(.plain).foregroundStyle(.secondary)
        }.padding(60).frame(maxWidth: .infinity)
    }

    private func shortcut(_ key: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Text(key).font(.system(size: 10)).padding(.horizontal, 4).padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(text).font(.system(size: 11))
        }
    }
}

struct CandidateReview: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text(model.isExecuting ? model.text("Перемещаем в Корзину") : model.recoveryRequired ? model.text("Проверьте предыдущий перенос") : model.transferReport != nil ? model.text("Результат переноса") : model.text("Проверить выбранное"))
                .font(.system(size: 25, weight: .semibold)).accessibilityHeading(.h1)
            if model.isExecuting {
                ProgressView(value: Double(model.transferProgress), total: Double(max(1, model.transferTotal)))
                Text(model.text("Обработано %@ из %@", model.text.number(model.transferProgress), model.text.number(model.transferTotal))).monospacedDigit()
                Spacer()
                Text(model.text("Остановка отменит следующие операции. Уже перемещённые файлы останутся в Корзине.")).foregroundStyle(.secondary)
                Button(model.text("Остановить после текущего файла")) { model.stopTransfer() }.modifier(NativeButtonStyle())
            } else if model.recoveryRequired {
                Text(model.text("Предыдущая операция не была полностью записана или завершена. Автоматического повторения нет. Проверьте исходную папку и Корзину."))
                    .foregroundStyle(.secondary)
                reportRows(model.recoveryEntries)
                Button(model.text("Открыть Корзину")) { openTrash() }.modifier(NativeButtonStyle())
                Button(model.text("Я проверил состояние файлов")) { model.acknowledgeRecovery() }.modifier(NativeButtonStyle())
            } else if let report = model.transferReport {
                Text(model.text("В Корзине: %@ · %@", model.text.number(report.successfulIDs.count), model.text.size(report.successfulBytes)))
                    .font(.headline)
                reportRows(report.entries)
                Text(model.text("Место на диске обычно возвращается после очистки Корзины в Finder. Приложение её не очищает."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Button(model.text("Открыть Корзину")) { openTrash() }.modifier(NativeButtonStyle())
            } else if model.session.staged.isEmpty {
                ContentUnavailableView(model.text("Файлы для удаления не выбраны"), systemImage: "checkmark.shield", description: Text(model.text("Все файлы остаются на месте.")))
            } else {
                Text(model.text("Исключите файлы, которые хотите оставить.")).foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.session.staged) { file in
                            HStack(spacing: 13) {
                                Image(systemName: file.icon).foregroundStyle(.blue)
                                    .accessibilityHidden(true)
                                Text(file.name).lineLimit(2).textSelection(.enabled)
                                Spacer()
                                Text(model.text.size(file.size)).foregroundStyle(.secondary).monospacedDigit()
                                Button(model.text("Оставить")) { model.keepCandidate(file.id) }.modifier(NativeButtonStyle())
                                    .accessibilityLabel(model.text("Оставить %@", file.name))
                                    .disabled(!model.isDemo && model.persistenceProblem != nil)
                            }.padding(.vertical, 13)
                            Divider()
                        }
                    }
                }
                Text(model.text.fileCount(model.session.staged.count) + " · " + model.text.size(model.session.stagedBytes))
                    .font(.headline)
            }
            if !model.isExecuting && !model.recoveryRequired && model.transferReport == nil {
                Label(model.isDemo ? model.text("Демонстрация не изменяет файлы.") : model.text("Файлы будут повторно проверены. Изменённые объекты будут пропущены."), systemImage: "lock.shield")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if !model.isExecuting && !model.recoveryRequired { HStack {
                Spacer()
                Button(model.text("Вернуться к разбору")) { model.isReviewing = false }.keyboardShortcut(.cancelAction).modifier(NativeButtonStyle())
                if model.canTransfer && model.transferReport == nil {
                    Button(model.text("Переместить %@ в Корзину", model.text.fileCount(model.session.staged.count))) { model.transferApprovedCandidates() }
                        .modifier(NativeButtonStyle(prominent: true))
                }
            } }
        }
        .padding(27).frame(width: 690, height: 500)
        .interactiveDismissDisabled(model.isExecuting || model.recoveryRequired)
    }
    private func reportRows(_ entries: [JournalEntry]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 13) {
                ForEach(entries) { entry in
                    HStack(alignment: .top) {
                        Text(entry.name).lineLimit(2)
                        Spacer()
                        Text(model.text(entry.state.title)).font(.system(size: 12)).foregroundStyle(entry.state == .trashed ? Color.secondary : Color.orange)
                    }
                    Divider()
                }
            }
        }
    }
    private func openTrash() {
        // Finder owns Trash recovery. This app never clears or restores it implicitly.
        if let trash = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            NSWorkspace.shared.open(trash)
        } else {
            model.error = "Откройте Корзину через значок в Dock или Finder. Автоматическое восстановление не выполняется."
        }
    }
}

struct NativeButtonStyle: ViewModifier {
    var prominent = false
    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            if prominent { content.buttonStyle(.glassProminent).buttonBorderShape(.capsule) }
            else { content.buttonStyle(.glass).buttonBorderShape(.capsule) }
        } else { fallback(content) }
        #else
        fallback(content)
        #endif
    }
    @ViewBuilder private func fallback(_ content: Content) -> some View {
        if prominent { content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule) }
        else { content.buttonStyle(.bordered).buttonBorderShape(.capsule) }
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: radius))
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
            } else { content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius)) }
            #else
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
            #endif
        }
    }
}

struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { GlassEffectContainer(spacing: 12, content: content) }
        else { content() }
        #else
        content()
        #endif
    }
}
