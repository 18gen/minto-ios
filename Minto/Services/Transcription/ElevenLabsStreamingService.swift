import Foundation

/// Streams base64-encoded 16-bit PCM audio to ElevenLabs Scribe v2 Realtime via WebSocket
/// and returns transcript segments in real time.
/// Note: Speaker diarization is not available in realtime mode.
final class ElevenLabsStreamingService: @unchecked Sendable {

    // MARK: - Types

    struct TranscriptResult: Sendable {
        let text: String
        let words: [Word]
        let isFinal: Bool
    }

    struct Word: Sendable {
        let text: String
        let start: Double
        let end: Double
        let confidence: Double
    }

    enum ServiceError: Error, LocalizedError {
        case noAPIKey
        case connectionFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "ElevenLabs API key not set"
            case .connectionFailed(let msg): return "ElevenLabs connection failed: \(msg)"
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

    var isConnected: Bool {
        lock.withLock { _isConnected }
    }

    // MARK: - Connect

    func connect() throws {
        let apiKey = AppSettings.elevenLabsKey
        guard !apiKey.isEmpty else { throw ServiceError.noAPIKey }

        let queryParams = [
            "model_id=scribe_v2_realtime",
            "audio_format=pcm_16000",
            "language_code=ja",
            "commit_strategy=vad",
            "vad_silence_threshold_secs=2.0",
            "include_timestamps=true",
        ].joined(separator: "&")

        guard let url = URL(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime?\(queryParams)") else {
            throw ServiceError.connectionFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)

        lock.withLock {
            self.urlSession = session
            self.webSocketTask = task
            _isConnected = true
        }

        task.resume()
        receiveLoop()
    }

    // MARK: - Send Audio

    func sendAudio(_ pcmData: Data) {
        guard let task = lock.withLock({ webSocketTask }), pcmData.count > 0 else { return }

        let base64Audio = pcmData.base64EncodedString()
        let message = #"{"message_type":"input_audio_chunk","audio_base_64":""# + base64Audio + #"","commit":false,"sample_rate":16000}"#

        task.send(.string(message)) { [weak self] error in
            if let error {
                self?.onError?(error)
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        let task = lock.withLock {
            let t = webSocketTask
            webSocketTask = nil
            _isConnected = false
            return t
        }

        task?.cancel(with: .normalClosure, reason: nil)

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

        guard let response = try? JSONDecoder().decode(ElevenLabsResponse.self, from: data) else {
            return
        }

        switch response.message_type {
        case "partial_transcript":
            guard let text = response.text, !text.isEmpty else { return }
            let words = mapWords(response.words)
            onTranscript?(TranscriptResult(text: text, words: words, isFinal: false))

        case "committed_transcript":
            guard let text = response.text, !text.isEmpty else { return }
            let words = mapWords(response.words)
            onTranscript?(TranscriptResult(text: text, words: words, isFinal: true))

        case "error":
            let errorMsg = response.text ?? "Unknown ElevenLabs error"
            onError?(ServiceError.connectionFailed(errorMsg))

        default:
            break // session_started, session_ended, etc.
        }
    }

    private func mapWords(_ words: [ElevenLabsWord]?) -> [Word] {
        (words ?? []).map { w in
            Word(
                text: w.text,
                start: w.start,
                end: w.end,
                confidence: exp(w.logprob ?? 0)
            )
        }
    }
}

// MARK: - Response Models

private struct ElevenLabsResponse: Decodable {
    let message_type: String
    let text: String?
    let words: [ElevenLabsWord]?
}

private struct ElevenLabsWord: Decodable {
    let text: String
    let start: Double
    let end: Double
    let logprob: Double?
    let speaker_id: String?
}
