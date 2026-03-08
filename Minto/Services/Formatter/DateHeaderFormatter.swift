import Foundation

enum DateHeaderFormatter {
    static let header: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return f
    }()

    static func string(_ date: Date) -> String { header.string(from: date) }
}
