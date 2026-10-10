import Foundation
import UniformTypeIdentifiers

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, english = "en", russian = "ru"
    public var id: Self { self }
    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        let match = Bundle.preferredLocalizations(from: ["en", "ru"], forPreferences: preferredLanguages).first
        return match == "ru" ? .russian : .english
    }
}

/// Store message keys, so changing language also updates existing errors and status.
public struct LocalizedMessage: ExpressibleByStringLiteral, Equatable, Sendable {
    public let key: String
    public let numbers: [Int]
    public init(stringLiteral value: String) { key = value; numbers = [] }
    public init(_ key: String, _ numbers: Int...) { self.key = key; self.numbers = numbers }
}

public struct Localizer: Sendable {
    public let language: AppLanguage
    public let locale: Locale
    public init(language: AppLanguage = .system, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.language = language.resolved(preferredLanguages: preferredLanguages)
        locale = Locale(identifier: self.language == .russian ? "ru_RU" : "en_US")
    }
    private static let resources: Bundle = {
        // SwiftPM's build path is not a distribution path. Prefer the packaged bundle.
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Unpile_UnpileCore.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        if let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("Unpile_UnpileCore.bundle")) { return bundle }
        #if DEBUG
        return Bundle.module
        #else
        fatalError("Missing bundled localizations")
        #endif
    }()
    private var translations: Bundle {
        Self.resources.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? Self.resources
    }
    public func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, arguments: arguments)
    }
    private func format(_ key: String, arguments: [CVarArg]) -> String {
        let value = translations.localizedString(forKey: key, value: key, table: nil)
        return arguments.isEmpty ? value : String(format: value, locale: locale, arguments: arguments)
    }
    public func render(_ message: LocalizedMessage) -> String { format(message.key, arguments: message.numbers.map { Int64($0) }) }
    public func number(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
    public func size(_ bytes: Int64) -> String { bytes.formatted(.byteCount(style: .file).locale(locale)) }
    public func date(_ date: Date) -> String { date.formatted(.dateTime.day().month().year().locale(locale)) }
    public func fileCount(_ count: Int) -> String {
        let key: String
        if language == .russian {
            let remainder = count % 100
            key = (11...14).contains(remainder) ? "count.files.many" : count % 10 == 1 ? "count.files.one" : (2...4).contains(count % 10) ? "count.files.few" : "count.files.many"
        } else { key = count == 1 ? "count.files.one" : "count.files.many" }
        return self(key, number(count))
    }
    public func typeLabel(_ file: FileRecord) -> String {
        guard let type = file.type else { return self("Файл") }
        if type.conforms(to: .pdf) { return self("PDF-документ") }
        if type.conforms(to: .image) { return self("%@ · изображение", file.url?.pathExtension.uppercased() ?? type.preferredFilenameExtension?.uppercased() ?? "") }
        if type.conforms(to: .movie) { return self("Видео") }
        if type.conforms(to: .audio) { return self("Аудио") }
        if type.conforms(to: .archive) { return self("Архив") }
        if type.conforms(to: .text) { return self("Текстовый документ") }
        return self("%@ · файл", (file.name as NSString).pathExtension.uppercased())
    }
    public static func catalog(language: AppLanguage) throws -> [String: String] {
        let text = Localizer(language: language)
        guard let url = text.translations.url(forResource: "Localizable", withExtension: "strings") else { throw CocoaError(.fileNoSuchFile) }
        return try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String] ?? [:]
    }
}
