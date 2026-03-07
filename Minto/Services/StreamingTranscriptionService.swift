import Foundation

/// Streams raw PCM audio to Deepgram Nova-3 via WebSocket and emits
/// partial (interim) and final transcript results.
final class StreamingTranscriptionService: @unchecked Sendable {
    private let lock = NSLock()
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var _isConnected = false

    var isConnected: Bool {
        lock.withLock { _isConnected }
    }

    // Callbacks — set before calling connect()
    var onPartial: ((String) -> Void)?
    var onFinal: ((String, Double, Double) -> Void)? // (text, startTime, duration)
    var onError: ((Error) -> Void)?

    func connect(
        apiKey: String,
        language: String = "ja",
        keywords: [String] = []
    ) {
        guard !apiKey.isEmpty else {
            onError?(StreamingError.noAPIKey)
            return
        }

        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        var queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "300"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
        ]

        // Boost proper nouns (attendee names, meeting terms)
        for keyword in keywords.prefix(50) {
            if let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryItems.append(URLQueryItem(name: "keywords", value: encoded))
            }
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            onError?(StreamingError.invalidURL)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)

        lock.withLock {
            self.urlSession = session
            self.webSocket = task
            self._isConnected = true
        }

        task.resume()
        print("[Deepgram] WebSocket connecting to \(url.host ?? "")")
        receiveLoop()
    }

    /// Send raw int16 PCM audio bytes to Deepgram.
    func sendAudio(_ data: Data) {
        guard lock.withLock({ _isConnected }), let ws = lock.withLock({ webSocket }) else { return }
        ws.send(.data(data)) { error in
            if let error {
                print("[Deepgram] Send error: \(error)")
            }
        }
    }

    /// Gracefully close the streaming session.
    func disconnect() {
        let ws = lock.withLock {
            _isConnected = false
            let task = webSocket
            webSocket = nil
            return task
        }

        guard let ws else { return }

        // Send Deepgram close message
        let closeMsg = Data("{\"type\": \"CloseStream\"}".utf8)
        ws.send(.data(closeMsg)) { _ in }

        // Allow a moment for Deepgram to send remaining finals, then cancel
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            ws.cancel(with: .normalClosure, reason: nil)
        }

        lock.withLock {
            urlSession?.invalidateAndCancel()
            urlSession = nil
        }

        print("[Deepgram] Disconnected")
    }

    // MARK: - Receive Loop

    private func receiveLoop() {
        let ws = lock.withLock { webSocket }
        guard let ws else { return }

        ws.receive { [weak self] result in
            guard let self else { return }
            guard self.lock.withLock({ self._isConnected }) else { return }

            switch result {
            case .success(.string(let text)):
                self.handleMessage(text)
            case .success(.data(let data)):
                if let text = String(data: data, encoding: .utf8) {
                    self.handleMessage(text)
                }
            case .failure(let error):
                if self.lock.withLock({ self._isConnected }) {
                    print("[Deepgram] Receive error: \(error)")
                    self.onError?(error)
                }
                return // stop loop
            @unknown default:
                break
            }

            self.receiveLoop()
        }
    }

    private func handleMessage(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)

            // Skip metadata and error messages
            guard response.type == "Results" else {
                if response.type == "Metadata" {
                    print("[Deepgram] Session started: \(response.metadata?.requestId ?? "?")")
                }
                return
            }

            let transcript = response.channel?.alternatives?.first?.transcript ?? ""

            // Skip empty transcripts
            guard !transcript.isEmpty else { return }

            let start = response.start ?? 0
            let duration = response.duration ?? 0

            if response.isFinal == true {
                onFinal?(transcript, start, duration)
            } else {
                onPartial?(transcript)
            }
        } catch {
            // Not all messages are transcript results (e.g. keepalive)
            // Silently ignore parse failures for non-result messages
        }
    }

    // MARK: - Errors

    enum StreamingError: LocalizedError {
        case noAPIKey
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Deepgram API key not configured"
            case .invalidURL: return "Failed to build Deepgram URL"
            }
        }
    }
}

// MARK: - Deepgram Response Models

private struct DeepgramResponse: Decodable {
    let type: String?
    let isFinal: Bool?
    let speechFinal: Bool?
    let channel: Channel?
    let start: Double?
    let duration: Double?
    let metadata: Metadata?

    enum CodingKeys: String, CodingKey {
        case type
        case isFinal = "is_final"
        case speechFinal = "speech_final"
        case channel, start, duration, metadata
    }

    struct Channel: Decodable {
        let alternatives: [Alternative]?
    }

    struct Alternative: Decodable {
        let transcript: String
        let confidence: Double?
    }

    struct Metadata: Decodable {
        let requestId: String?

        enum CodingKeys: String, CodingKey {
            case requestId = "request_id"
        }
    }
}
