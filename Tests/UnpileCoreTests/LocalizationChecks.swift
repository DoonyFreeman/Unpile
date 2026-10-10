import Foundation
import UnpileCore
import UnpileFilesystem

struct LocalizationChecks {
    static func completeCatalogsAndMatchingPlaceholders() throws {
        let english = try Localizer.catalog(language: .english)
        let russian = try Localizer.catalog(language: .russian)
        try expect(english.count >= 150 && Set(english.keys) == Set(russian.keys), "Catalog missing entries")
        let placeholders = try NSRegularExpression(pattern: "%(@|lld)")
        for (key, value) in english {
            let source = russian[key]!
            func formats(_ text: String) -> [String] {
                placeholders.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }
            }
            try expect(formats(value) == formats(source) && !value.isEmpty && !source.isEmpty, "Format placeholder mismatch")
            if key != "Русский" {
                try expect(value.range(of: "[А-Яа-яЁё]", options: .regularExpression) == nil, "Untranslated English entry")
            }
        }
        for error in [InventoryError.invalidFolder, .protectedFolder, .unsupportedVolume, .cannotRead] {
            try expect(english[error.localizedDescription] != nil, "Inventory error untranslated")
        }
        for order in FileOrder.allCases { try expect(english[order.title] != nil, "Order untranslated") }
        for state in [TransferState.waiting, .processing, .trashed, .changed, .failed, .cancelled] {
            try expect(english[state.title] != nil, "Transfer result untranslated")
        }
    }

    static func languageSelectionAndStoredMessages() throws {
        try expect(AppLanguage.system.resolved(preferredLanguages: ["ru-RU", "en"]) == .russian, "System Russian missing")
        try expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]) == .english, "Fallback is not English")
        try expect(AppLanguage.english.resolved(preferredLanguages: ["ru"]) == .english, "Explicit language ignored")
        let message = LocalizedMessage("В Корзине: %lld. Остальные файлы не считаются перемещёнными.", 3)
        let english = Localizer(language: .english)
        let russian = Localizer(language: .russian)
        try expect(english("Оставить") == "Keep" && russian("Оставить") == "Оставить", "Resource bundle lookup failed")
        try expect(english.render(message).hasPrefix("In Trash: 3.") && russian.render(message).hasPrefix("В Корзине: 3."), "Stored message did not change language")
        try expect(english("Оставить %@", "100% synthetic.txt") == "Keep 100% synthetic.txt", "Filename interpreted as format")
    }

    static func numbersDatesSizesAndPluralForms() throws {
        let english = Localizer(language: .english)
        let russian = Localizer(language: .russian)
        for (count, noun) in [(0, "файлов"), (1, "файл"), (2, "файла"), (5, "файлов"), (11, "файлов"), (14, "файлов"), (21, "файл"), (22, "файла"), (111, "файлов")] {
            try expect(russian.fileCount(count) == "\(count) \(noun)", "Russian plural form failed")
        }
        try expect(english.fileCount(1) == "1 file" && english.fileCount(21) == "21 files", "English plural form failed")
        try expect(english.number(12345) != russian.number(12345), "Number locale ignored")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try expect(english.date(date) != russian.date(date), "Date locale ignored")
        try expect(!english.size(123_000).isEmpty && !russian.size(123_000).isEmpty && !english.size(Int64.max).isEmpty, "Size formatting failed")
        let file = FileRecord(name: "sample.pdf", size: 10, modified: date)
        try expect(english.typeLabel(file) == "PDF document" && russian.typeLabel(file) == "PDF-документ", "Type description untranslated")
    }
}
