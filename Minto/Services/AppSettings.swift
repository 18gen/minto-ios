import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var defaultToneMode: String {
        didSet { defaults.set(defaultToneMode, forKey: "defaultToneMode") }
    }
    var autoRecord: Bool {
        didSet { defaults.set(autoRecord, forKey: "autoRecord") }
    }

    // Thread-safe static accessors — reads from Xcode scheme environment variables
    static var whisperKey: String { ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "" }
    static var claudeKey: String { ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "" }
    static var deepgramKey: String { ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] ?? "" }

    private init() {
        self.defaultToneMode = defaults.string(forKey: "defaultToneMode") ?? "business"
        self.autoRecord = defaults.bool(forKey: "autoRecord")
    }
}
