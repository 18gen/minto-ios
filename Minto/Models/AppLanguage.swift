import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ja
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ja: "Japanese (日本語)"
        case .en: "English"
        }
    }
}
