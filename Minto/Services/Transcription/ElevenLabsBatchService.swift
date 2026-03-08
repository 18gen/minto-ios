import Foundation

/// Post-recording batch transcription via ElevenLabs Scribe v2.
/// Provides full speaker diarization (up to 48 speakers).
actor ElevenLabsBatchService {

    // MARK: - Types

    struct BatchResult: Sendable {
        let text: String
        let utterances: [Utterance]
    }

    struct Utterance: Sendable {
        let text: String
        let start: Double
        let end: Double
        let speakerId: String
    }

    enum BatchError: Error, LocalizedError {
        case noAPIKey
        case httpError(Int, String)
        case decodingError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "ElevenLabs API key not set"
            case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
            case .decodingError(let msg): return "Decoding error: \(msg)"
            }
        }
    }

    // MARK: - Public

    func transcribe(audioFileURL: URL) async throws -> BatchResult {
        let apiKey = AppSettings.elevenLabsKey
        guard !apiKey.isEmpty else { throw BatchError.noAPIKey }

        let audioData = try Data(contentsOf: audioFileURL)

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendField(boundary: boundary, name: "file",
                         filename: audioFileURL.lastPathComponent,
                         mimeType: "audio/wav", data: audioData)
        body.appendField(boundary: boundary, name: "model_id", value: "scribe_v2")
        body.appendField(boundary: boundary, name: "language_code", value: "ja")
        body.appendField(boundary: boundary, name: "diarize", value: "true")
        body.appendField(boundary: boundary, name: "timestamps_granularity", value: "word")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BatchError.httpError(0, "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BatchError.httpError(httpResponse.statusCode, errorBody)
        }

        return try decodeBatchResponse(data)
    }

    // MARK: - Private

    private func decodeBatchResponse(_ data: Data) throws -> BatchResult {
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)

            let utterances = (response.utterances ?? []).map { u in
                Utterance(
                    text: u.text,
                    start: u.start,
                    end: u.end,
                    speakerId: u.speaker_id ?? "speaker_0"
                )
            }

            return BatchResult(text: response.text ?? "", utterances: utterances)
        } catch {
            throw BatchError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Response Models

private struct Response: Decodable {
    let text: String?
    let utterances: [ResponseUtterance]?
}

private struct ResponseUtterance: Decodable {
    let text: String
    let start: Double
    let end: Double
    let speaker_id: String?
}

// MARK: - Multipart Helpers

private extension Data {
    mutating func appendField(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }

    mutating func appendField(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
