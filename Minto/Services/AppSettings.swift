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

    // WebSocket services (Deepgram, ElevenLabs Realtime) still need client-side keys
    // since Cloudflare Workers free tier doesn't support WebSocket proxying.
    // REST services now use the proxy — these env vars are only for local development.
    nonisolated static var whisperKey: String { ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "" }
    nonisolated static var claudeKey: String { ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "" }
    nonisolated static var deepgramKey: String { ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] ?? "" }
    nonisolated static var elevenLabsKey: String { ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? "" }

    private init() {
        self.defaultToneMode = defaults.string(forKey: "defaultToneMode") ?? "business"
        self.autoRecord = defaults.bool(forKey: "autoRecord")
    }
}
