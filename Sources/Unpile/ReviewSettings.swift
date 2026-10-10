import SwiftUI
import UnpileCore

struct ReviewSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(model.text("Настройки разбора")).font(.system(size: 25, weight: .semibold)).accessibilityHeading(.h1)
                Spacer()
                Button(model.text("Готово")) { model.isSettingsPresented = false }.keyboardShortcut(.cancelAction).modifier(NativeButtonStyle())
            }
            Picker(model.text("Язык интерфейса"), selection: $model.language) {
                Text(model.text("Как в системе")).tag(AppLanguage.system)
                Text("English").tag(AppLanguage.english)
                Text(model.text("Русский")).tag(AppLanguage.russian)
            }
            Form {
                Picker(model.text("Файлов за сессию"), selection: $model.sessionLimit) {
                    ForEach([20, 50, 100], id: \.self) { Text(model.text.number($0)).tag($0) }
                }
                Picker(model.text("Порядок"), selection: $model.order) {
                    ForEach(FileOrder.allCases) { Text(model.text($0.title)).tag($0) }
                }
                Toggle(model.text("Включать изменённые за последние 24 часа"), isOn: $model.includeRecent)
                    .disabled(model.isDemo)
            }.disabled(!model.canChangePreferences)
            if !model.canChangePreferences {
                Text(model.persistenceProblem != nil ? model.text("Параметры станут доступны после восстановления сохранения.") : model.text("Параметры можно изменить перед первым решением. Для новой очереди начните следующий разбор."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Divider()
            Label(model.isDemo ? model.text("Демо не сохраняет решения") : model.persistenceProblem != nil ? model.text("Сохранение требует внимания") : model.text("Решения сохраняются на этом Mac"), systemImage: "lock.shield")
                .font(.headline)
            Text(model.text("Оставленные файлы пропускаются до изменения или пересмотра. «Позже» вернётся в следующем разборе. Кандидаты после запуска ждут проверки списка."))
                .font(.callout).foregroundStyle(.secondary)
            if let problem = model.persistenceProblem {
                Text(model.text.render(problem)).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
                if model.canRetrySaving { Button(model.text("Повторить сохранение")) { model.retrySaving() }.modifier(NativeButtonStyle()) }
            }
            HStack {
                if model.hasSession && model.persistenceProblem == nil {
                    Button(model.text("Следующий разбор")) { model.isSettingsPresented = false; model.beginAgain() }.modifier(NativeButtonStyle())
                }
                if model.rememberedCount > 0 && !model.isDemo {
                    Button(model.text("Пересмотреть оставленные · %@", model.text.number(model.rememberedCount))) { model.reconsiderKept() }.modifier(NativeButtonStyle())
                }
            }
            Button(model.text("Сбросить сохранённые решения…")) { model.forgetReview() }
                .modifier(NativeButtonStyle()).disabled(model.isExecuting || model.recoveryRequired)
            Text(model.text("Сброс очищает память приложения. Он не перемещает и не удаляет файлы."))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(27).frame(width: 560)
    }
}
