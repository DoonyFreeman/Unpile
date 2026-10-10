import SwiftUI
import AppKit

struct BrandIcon: View {
    var size: CGFloat
    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
