import SwiftUI
import AppKit

@main
struct UnpileApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("Unpile", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 760, minHeight: 640)
        }
        .defaultSize(width: 980, height: 840)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(model.text("Выбрать папку…")) { model.chooseFolder() }.keyboardShortcut("o").disabled(!model.canSwitchFolder)
                Button(model.text("Демонстрация")) { model.showDemo() }.disabled(!model.canSwitchFolder)
                Button(model.text("Отключить папку")) { model.disconnect() }.disabled(!model.hasSession || !model.canSwitchFolder)
            }
            CommandGroup(replacing: .undoRedo) {
                Button(model.text("Отменить решение")) { model.undo() }.keyboardShortcut("z").disabled(!model.session.canUndo || !model.canDecide)
            }
            CommandGroup(replacing: .appSettings) {
                Button(model.text("Настройки разбора…")) { model.isSettingsPresented = true }.keyboardShortcut(",")
                    .disabled(!model.canSwitchFolder)
            }
        }
    }
}
