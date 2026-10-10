import SwiftUI
import UnpileCore

struct FileCard: View {
    let file: FileRecord
    let text: Localizer
    let enabled: Bool
    let preview: () -> Void
    let decide: (Decision) -> Void
    @State private var translation = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState(for: .voiceOver) private var isMetadataFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let threshold = max(80, min(130, geometry.size.width * 0.23))
            let progress = min(1, abs(translation) / threshold)
            let accent: Color = translation < 0 ? .red : .mint
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(.background)
                    .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(.primary.opacity(0.04)) }
                    .padding(.horizontal, 21).offset(y: 14).rotationEffect(.degrees(reduceMotion ? 0 : -2))
                RoundedRectangle(cornerRadius: 30).fill(.background)
                    .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(.primary.opacity(0.06)) }
                    .padding(.horizontal, 10).offset(y: 8).rotationEffect(.degrees(reduceMotion ? 0 : 1))
                VStack(alignment: .leading, spacing: 0) {
                    FilePreview(file: file, text: text).frame(height: 250).clipped()
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 11) {
                            Image(systemName: file.icon).foregroundStyle(.blue).frame(width: 35, height: 39)
                                .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(file.name).font(.system(size: 18, weight: .semibold)).tracking(-0.3).lineLimit(2).help(file.name).textSelection(.enabled)
                                Text(text.size(file.size) + " · " + text.date(file.modified))
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityLabel(file.name + ", " + text.size(file.size) + ", " + text("Дата изменения: %@", text.date(file.modified)))
                        .accessibilityFocused($isMetadataFocused)
                        HStack {
                            Button { preview() } label: { Label(text("Быстрый просмотр"), systemImage: "viewfinder") }
                                .modifier(NativeButtonStyle()).controlSize(.small).keyboardShortcut(.space, modifiers: [])
                                .disabled(!file.supportsPreview)
                            if let url = file.url {
                                Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Label(text("В Finder"), systemImage: "folder") }
                                    .modifier(NativeButtonStyle()).controlSize(.small)
                            }
                        }
                    }.padding(19)
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 30))
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .overlay { RoundedRectangle(cornerRadius: 30).fill(accent.opacity(progress * 0.09)).allowsHitTesting(false) }
                .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(progress > 0 ? accent.opacity(progress * 0.75) : .primary.opacity(0.09), lineWidth: progress > 0 ? 2 : 1) }
                .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
                .overlay(alignment: translation < 0 ? .topLeading : .topTrailing) {
                    if abs(translation) > 12 {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(translation < 0 ? text("На удаление") : text("Оставить"), systemImage: translation < 0 ? "trash" : "checkmark")
                                .font(.system(size: 16, weight: .bold))
                            Text(progress >= 1 ? text("Отпустите, чтобы выбрать") : text("Продолжайте свайп"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(accent).padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(accent.opacity(0.5)) }
                        .rotationEffect(.degrees(reduceMotion ? 0 : translation < 0 ? -5 : 5))
                        .padding(20).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .offset(x: reduceMotion ? 0 : max(-180, min(180, translation * 0.55)))
                .rotationEffect(.degrees(reduceMotion ? 0 : max(-7, min(7, translation / 35))))
                .gesture(DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        guard enabled, abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        translation = value.translation.width
                    }
                    .onEnded { value in
                        let offset = value.translation
                        let decision: Decision? = enabled && abs(offset.width) >= threshold && abs(offset.width) > abs(offset.height) * 1.35
                            ? (offset.width < 0 ? .stage : .keep) : nil
                        finishSwipe(decision)
                    })
            }
            .background {
                TrackpadSwipeInput(enabled: enabled, onProgress: { translation = $0 }, onFinish: finishSwipe)
            }
        }.frame(height: 390)
            .accessibilityElement(children: .contain)
            .onAppear { isMetadataFocused = true }
            .onChange(of: enabled) { _, isEnabled in if !isEnabled { translation = 0 } }
    }

    private func finishSwipe(_ decision: Decision?) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8)) { translation = 0 }
        if enabled, let decision { decide(decision) }
    }
}

struct FilePreview: View {
    let file: FileRecord
    let text: Localizer
    @StateObject private var thumbnail = ThumbnailModel()
    var body: some View {
        ZStack {
            Color.blue.opacity(0.08)
            if let image = thumbnail.image {
                Image(nsImage: image).resizable().scaledToFit().padding(8)
            } else if file.url == nil && (file.type?.conforms(to: .movie) == true || file.type?.conforms(to: .image) == true) {
                MountainScene()
            } else if file.url == nil && file.type?.conforms(to: .pdf) == true {
                DemoDocument()
            } else {
                VStack(spacing: 13) {
                    Image(systemName: file.icon).font(.system(size: 56, weight: .light)).foregroundStyle(.blue.gradient)
                    Text(thumbnail.isLoading ? text("Готовим превью…") : text.typeLabel(file)).font(.system(size: 12)).foregroundStyle(.secondary)
                    if thumbnail.isLoading { ProgressView().controlSize(.small) }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Label(text.typeLabel(file), systemImage: file.icon).font(.system(size: 11))
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule()).padding(14)
        }
        .onAppear { thumbnail.load(file) }
        .onChange(of: file.id) { _, _ in thumbnail.load(file) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text("Превью: %@", file.name))
        .accessibilityAddTraits(.isImage)
    }
}

struct MountainScene: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 0.64, green: 0.78, blue: 0.9), Color(red: 0.96, green: 0.84, blue: 0.76)], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 0.96, green: 0.85, blue: 0.75)).frame(width: 50, height: 50).position(x: width * 0.73, y: height * 0.24)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.7))
                    for point in [(0.13, 0.4), (0.24, 0.52), (0.4, 0.2), (0.56, 0.56), (0.64, 0.34), (0.8, 0.56), (0.87, 0.3), (1, 0.65), (1, 1), (0, 1)] {
                        path.addLine(to: CGPoint(x: width * point.0, y: height * point.1))
                    }
                }.fill(Color(red: 0.48, green: 0.58, blue: 0.61))
                Path { path in
                    path.move(to: CGPoint(x: width * 0.31, y: height * 0.37))
                    for point in [(0.4, 0.2), (0.49, 0.4), (0.42, 0.34), (0.38, 0.4), (0.36, 0.32)] {
                        path.addLine(to: CGPoint(x: width * point.0, y: height * point.1))
                    }
                }.fill(Color(red: 0.88, green: 0.93, blue: 0.95))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.71))
                    for point in [(0.2, 0.46), (0.4, 0.74), (0.78, 0.47), (1, 0.64), (1, 1), (0, 1)] {
                        path.addLine(to: CGPoint(x: width * point.0, y: height * point.1))
                    }
                }.fill(Color(red: 0.26, green: 0.43, blue: 0.47))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.87))
                    path.addQuadCurve(to: CGPoint(x: width, y: height * 0.67), control: CGPoint(x: width * 0.7, y: height * 0.51))
                    path.addLine(to: CGPoint(x: width, y: height)); path.addLine(to: CGPoint(x: 0, y: height))
                }.fill(Color(red: 0.15, green: 0.29, blue: 0.33))
                if width > 200 { Image(systemName: "play.fill").font(.system(size: 18)).foregroundStyle(.primary).frame(width: 54, height: 54).background(.regularMaterial, in: Circle()) }
            }
        }.accessibilityHidden(true)
    }
}

private struct DemoDocument: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Workshop\nnotes").font(.system(size: 17, weight: .semibold))
            ForEach(0..<6) { index in Capsule().fill(.secondary.opacity(0.2)).frame(width: index % 3 == 0 ? 85 : 110, height: 3) }
        }
        .padding(22).background(.background, in: RoundedRectangle(cornerRadius: 8))
        .rotationEffect(.degrees(-3)).shadow(color: .black.opacity(0.12), radius: 15, y: 8)
    }
}
