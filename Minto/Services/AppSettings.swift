import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var whisperAPIKey: String {
        didSet { defaults.set(whisperAPIKey, forKey: "whisperAPIKey") }
    }
    var claudeAPIKey: String {
        didSet { defaults.set(claudeAPIKey, forKey: "claudeAPIKey") }
    }
    var deepgramAPIKey: String {
        didSet { defaults.set(deepgramAPIKey, forKey: "deepgramAPIKey") }
    }
    var defaultToneMode: String {
        didSet { defaults.set(defaultToneMode, forKey: "defaultToneMode") }
    }
    var autoRecord: Bool {
        didSet { defaults.set(autoRecord, forKey: "autoRecord") }
    }
    var googleClientID: String {
        didSet { defaults.set(googleClientID, forKey: "googleClientID") }
    }
    var googleClientSecret: String {
        didSet { defaults.set(googleClientSecret, forKey: "googleClientSecret") }
    }

    var hasWhisperKey: Bool { !whisperAPIKey.isEmpty }
    var hasClaudeKey: Bool { !claudeAPIKey.isEmpty }
    var hasDeepgramKey: Bool { !deepgramAPIKey.isEmpty }

    // Thread-safe static accessors for use from actors/background contexts
    static var whisperKey: String { UserDefaults.standard.string(forKey: "whisperAPIKey") ?? "" }
    static var claudeKey: String { UserDefaults.standard.string(forKey: "claudeAPIKey") ?? "" }
    static var deepgramKey: String { UserDefaults.standard.string(forKey: "deepgramAPIKey") ?? "" }

    private init() {
        self.whisperAPIKey = defaults.string(forKey: "whisperAPIKey") ?? ""
        self.claudeAPIKey = defaults.string(forKey: "claudeAPIKey") ?? ""
        self.deepgramAPIKey = defaults.string(forKey: "deepgramAPIKey") ?? ""
        self.defaultToneMode = defaults.string(forKey: "defaultToneMode") ?? "business"
        self.autoRecord = defaults.bool(forKey: "autoRecord")
        self.googleClientID = defaults.string(forKey: "googleClientID") ?? ""
        self.googleClientSecret = defaults.string(forKey: "googleClientSecret") ?? ""
    }
}
