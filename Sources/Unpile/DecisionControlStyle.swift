import SwiftUI

struct DecisionControlStyle: ButtonStyle {
    let accent: Color
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .modifier(GlassSurface(radius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22).strokeBorder(accent.opacity(configuration.isPressed ? 0.6 : 0.2))
            }
            .shadow(color: accent.opacity(enabled ? 0.08 : 0), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
