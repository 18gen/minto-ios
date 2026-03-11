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

    // MARK: - API Proxy

    /// Base URL for the Cloudflare Worker proxy that holds API keys server-side.
    /// REST endpoints (Claude, Whisper, ElevenLabs batch) go through this proxy.
    nonisolated static let apiProxyBase = "https://minto-api.ichihashigen.workers.dev"

    // MARK: - API Keys

    // Keys are fetched from the server proxy on launch.
    // Environment variables are used as fallback for local Xcode development.
    private static let keyLock = NSLock()
    private static var _elevenLabsKey: String = ""
    private static var _deepgramKey: String = ""
    private(set) static var keysFetched = false

    nonisolated static var whisperKey: String { ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "" }
    nonisolated static var claudeKey: String { ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "" }

    nonisolated static var deepgramKey: String {
        keyLock.lock()
        let key = _deepgramKey
        keyLock.unlock()
        if !key.isEmpty { return key }
        return ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] ?? ""
    }

    nonisolated static var elevenLabsKey: String {
        keyLock.lock()
        let key = _elevenLabsKey
        keyLock.unlock()
        if !key.isEmpty { return key }
        return ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? ""
    }

    /// Fetch WebSocket API keys from the server proxy. Called on app launch.
    nonisolated static func fetchKeys() async {
        guard let url = URL(string: "\(apiProxyBase)/v1/keys") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
            keyLock.lock()
            if let key = json["elevenlabs"], !key.isEmpty { _elevenLabsKey = key }
            if let key = json["deepgram"], !key.isEmpty { _deepgramKey = key }
            keyLock.unlock()
            keysFetched = true
        } catch {
            // Silently fail — env var fallback will be used
        }
    }

    private init() {
        self.defaultToneMode = defaults.string(forKey: "defaultToneMode") ?? "business"
        self.autoRecord = defaults.bool(forKey: "autoRecord")
    }
}
