import Foundation
import Observation
import os

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Minto", category: "AppSettings")

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }
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

    // Keys are fetched from the server proxy on launch, then cached in Keychain.
    // Environment variables are used as fallback for local Xcode development.
    private static let keyLock = NSLock()
    private static var _elevenLabsKey: String = ""
    private static var _deepgramKey: String = ""
    private(set) static var keysFetched = false

    /// Continuation resumed when key fetching completes (success or final failure).
    private static var readyContinuations: [CheckedContinuation<Void, Never>] = []
    private static let readyLock = NSLock()

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

    /// Wait until key fetching has completed, with a timeout.
    nonisolated static func awaitKeysReady(timeout: TimeInterval = 10) async {
        if keysFetched { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    readyLock.lock()
                    if keysFetched {
                        readyLock.unlock()
                        continuation.resume()
                    } else {
                        readyContinuations.append(continuation)
                        readyLock.unlock()
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
            }
            // Return as soon as either completes
            await group.next()
            group.cancelAll()
        }
    }

    /// Fetch WebSocket API keys from the server proxy. Called on app launch.
    /// Loads cached keys from Keychain first, then refreshes from server with retry.
    nonisolated static func fetchKeys() async {
        // 1. Load cached keys from Keychain immediately
        loadCachedKeys()

        // 2. Fetch fresh keys from server with retry
        guard let url = URL(string: "\(apiProxyBase)/v1/keys") else {
            signalReady()
            return
        }

        var request = URLRequest(url: url)
        request.setValue("com.genichihashi.Minto", forHTTPHeaderField: "X-App-Bundle")

        for attempt in 1 ... 3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    log.warning("fetchKeys attempt \(attempt): invalid response type")
                    continue
                }
                guard http.statusCode == 200 else {
                    log.warning("fetchKeys attempt \(attempt): HTTP \(http.statusCode)")
                    if attempt < 3 { try await Task.sleep(for: .seconds(attempt * 2)) }
                    continue
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    log.warning("fetchKeys attempt \(attempt): invalid JSON")
                    if attempt < 3 { try await Task.sleep(for: .seconds(attempt * 2)) }
                    continue
                }

                applyFetchedKeys(json)
                saveKeysToKeychain()
                log.info("fetchKeys: success on attempt \(attempt)")
                signalReady()
                return
            } catch {
                log.error("fetchKeys attempt \(attempt): \(error.localizedDescription)")
                if attempt < 3 { try? await Task.sleep(for: .seconds(attempt * 2)) }
            }
        }

        log.error("fetchKeys: all retries exhausted")
        signalReady()
    }

    // MARK: - Key Helpers

    private static func applyFetchedKeys(_ json: [String: String]) {
        keyLock.withLock {
            if let key = json["elevenlabs"], !key.isEmpty { _elevenLabsKey = key }
            if let key = json["deepgram"], !key.isEmpty { _deepgramKey = key }
        }
    }

    // MARK: - Keychain Cache

    private static func loadCachedKeys() {
        if let el = KeychainService.loadToken(forKey: "elevenlabs_api_key"), !el.isEmpty {
            keyLock.withLock { if _elevenLabsKey.isEmpty { _elevenLabsKey = el } }
            log.debug("Loaded ElevenLabs key from Keychain")
        }
        if let dg = KeychainService.loadToken(forKey: "deepgram_api_key"), !dg.isEmpty {
            keyLock.withLock { if _deepgramKey.isEmpty { _deepgramKey = dg } }
            log.debug("Loaded Deepgram key from Keychain")
        }
    }

    private static func saveKeysToKeychain() {
        let (el, dg) = keyLock.withLock { (_elevenLabsKey, _deepgramKey) }
        if !el.isEmpty { KeychainService.saveToken(el, forKey: "elevenlabs_api_key") }
        if !dg.isEmpty { KeychainService.saveToken(dg, forKey: "deepgram_api_key") }
    }

    private static func signalReady() {
        keysFetched = true
        readyLock.lock()
        let continuations = readyContinuations
        readyContinuations.removeAll()
        readyLock.unlock()
        for c in continuations { c.resume() }
    }

    private init() {
        self.language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .ja
        self.defaultToneMode = defaults.string(forKey: "defaultToneMode") ?? "business"
        self.autoRecord = defaults.bool(forKey: "autoRecord")
    }
}
