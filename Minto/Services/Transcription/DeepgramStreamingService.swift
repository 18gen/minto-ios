import Foundation

/// Streams raw 16-bit PCM audio to Deepgram Nova-3 via WebSocket and returns
/// speaker-diarized transcript segments in real time.
final class DeepgramStreamingService: @unchecked Sendable {

    // MARK: - Types

    struct TranscriptResult: Sendable {
        let text: String
        let words: [Word]
        let isFinal: Bool
    }

    struct Word: Sendable {
        let word: String
        let start: Double
        let end: Double
        let confidence: Double
        let speaker: Int
    }

    enum ServiceError: Error, LocalizedError {
        case noAPIKey
        case connectionFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Deepgram API key not set"
            case .connectionFailed(let msg): return "Deepgram connection failed: \(msg)"
            }
        }
    }

    // MARK: - Callbacks

    var onTranscript: ((TranscriptResult) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Private

    private let lock = NSLock()
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var _isConnected = false
    private var keepAliveTimer: Timer?

    var isConnected: Bool {
        lock.withLock { _isConnected }
    }

    // MARK: - Connect

    func connect() throws {
        let apiKey = AppSettings.deepgramKey
        guard !apiKey.isEmpty else { throw ServiceError.noAPIKey }

        let queryParams = [
            "model=nova-3",
            "encoding=linear16",
            "sample_rate=16000",
            "channels=1",
            "diarize=true",
            "language=ja",
            "smart_format=true",
            "punctuate=true",
            "interim_results=true",
        ].joined(separator: "&")

        guard let url = URL(string: "wss://api.deepgram.com/v1/listen?\(queryParams)") else {
            throw ServiceError.connectionFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)

        lock.withLock {
            self.urlSession = session
            self.webSocketTask = task
        }

        task.resume()

        lock.withLock { _isConnected = true }

        receiveLoop()
        startKeepAlive()
    }

    // MARK: - Send Audio

    /// Send raw Int16 PCM bytes (no WAV header) to Deepgram.
    func sendAudio(_ pcmData: Data) {
        guard let task = lock.withLock({ webSocketTask }), pcmData.count > 0 else { return }
        task.send(.data(pcmData)) { [weak self] error in
            if let error {
                self?.onError?(error)
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        lock.withLock {
            keepAliveTimer?.invalidate()
            keepAliveTimer = nil
        }

        // Send close message per Deepgram protocol: empty JSON `{ "type": "CloseStream" }`
        if let task = lock.withLock({ webSocketTask }) {
            let closeMessage = #"{"type":"CloseStream"}"#
            task.send(.string(closeMessage)) { _ in }
            task.cancel(with: .normalClosure, reason: nil)
        }

        lock.withLock {
            webSocketTask = nil
            _isConnected = false
        }

        urlSession?.invalidateAndCancel()
        lock.withLock { urlSession = nil }
    }

    // MARK: - Receive Loop

    private func receiveLoop() {
        guard let task = lock.withLock({ webSocketTask }) else { return }

        task.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveLoop()

            case .failure(let error):
                let wasConnected = self.lock.withLock {
                    let was = self._isConnected
                    self._isConnected = false
                    return was
                }
                if wasConnected {
                    self.onError?(error)
                }
            }
        }
    }

    // MARK: - Parse Response

    private func handleMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)

            guard response.type == "Results",
                  let channel = response.channel,
                  let alt = channel.alternatives.first,
                  !alt.transcript.isEmpty else { return }

            let words = alt.words?.map { w in
                Word(word: w.word, start: w.start, end: w.end,
                     confidence: w.confidence, speaker: w.speaker ?? 0)
            } ?? []

            let result = TranscriptResult(
                text: alt.transcript,
                words: words,
                isFinal: response.is_final ?? false
            )

            onTranscript?(result)
        } catch {
            // Non-result messages (metadata, etc.) — ignore
        }
    }

    // MARK: - Keep-Alive

    private func startKeepAlive() {
        lock.withLock {
            keepAliveTimer?.invalidate()
            keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
                guard let self, let task = self.lock.withLock({ self.webSocketTask }) else { return }
                let keepAlive = #"{"type":"KeepAlive"}"#
                task.send(.string(keepAlive)) { _ in }
            }
        }
    }
}

// MARK: - Deepgram JSON Models

private struct DeepgramResponse: Decodable {
    let type: String
    let is_final: Bool?
    let channel: Channel?

    struct Channel: Decodable {
        let alternatives: [Alternative]
    }

    struct Alternative: Decodable {
        let transcript: String
        let words: [DeepgramWord]?
    }

    struct DeepgramWord: Decodable {
        let word: String
        let start: Double
        let end: Double
        let confidence: Double
        let speaker: Int?
    }
}
