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
        case httpError(Int, String)
        case decodingError(String)

        var errorDescription: String? {
            switch self {
            case let .httpError(code, msg): "HTTP \(code): \(msg)"
            case let .decodingError(msg): "Decoding error: \(msg)"
            }
        }
    }

    // MARK: - Public

    func transcribe(audioFileURL: URL) async throws -> BatchResult {
        let audioData = try Data(contentsOf: audioFileURL)

        let boundary = UUID().uuidString
        // swiftlint:disable:next force_unwrapping
        var request = URLRequest(url: URL(string: "\(AppSettings.apiProxyBase)/v1/elevenlabs/stt")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendMultipartField(boundary: boundary, name: "file",
                                  filename: audioFileURL.lastPathComponent,
                                  mimeType: "audio/wav", data: audioData)
        body.appendMultipartField(boundary: boundary, name: "model_id", value: "scribe_v2")
        body.appendMultipartField(boundary: boundary, name: "language_code", value: "ja")
        body.appendMultipartField(boundary: boundary, name: "diarize", value: "true")
        body.appendMultipartField(boundary: boundary, name: "timestamps_granularity", value: "word")
        body.append(Data("--\(boundary)--\r\n".utf8))

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

    private nonisolated func decodeBatchResponse(_ data: Data) throws -> BatchResult {
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

private struct Response: Decodable, Sendable {
    let text: String?
    let utterances: [ResponseUtterance]?
}

private struct ResponseUtterance: Decodable, Sendable {
    let text: String
    let start: Double
    let end: Double
    let speaker_id: String?
}
