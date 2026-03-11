import Foundation

enum DateHeaderFormatter {
    static func string(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: AppSettings.shared.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return f.string(from: date)
    }
}
