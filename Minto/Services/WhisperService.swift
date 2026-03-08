import Foundation

actor WhisperService {
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")! // swiftlint:disable:this force_unwrapping

    struct VerboseResult: Decodable, Sendable {
        let text: String
        let segments: [Segment]?

        struct Segment: Decodable, Sendable {
            let start: Double
            let end: Double
            let text: String
        }
    }

    enum WhisperError: Error, LocalizedError {
        case noAPIKey
        case httpError(Int, String)
        case decodingError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: "Whisper API key not set"
            case let .httpError(code, msg): "HTTP \(code): \(msg)"
            case let .decodingError(msg): "Decoding error: \(msg)"
            }
        }
    }

    func transcribe(audioData: Data) async throws -> VerboseResult {
        let apiKey = AppSettings.whisperKey
        guard !apiKey.isEmpty else { throw WhisperError.noAPIKey }

        let boundary = UUID().uuidString
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "file", filename: "audio.wav", mimeType: "audio/wav", data: audioData)
        body.appendMultipart(boundary: boundary, name: "model", value: "whisper-1")
        body.appendMultipart(boundary: boundary, name: "language", value: "ja")
        body.appendMultipart(boundary: boundary, name: "response_format", value: "verbose_json")
        body.append(Data("--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.httpError(0, "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.httpError(httpResponse.statusCode, errorBody)
        }

        do {
            return try JSONDecoder().decode(VerboseResult.self, from: data)
        } catch {
            throw WhisperError.decodingError(error.localizedDescription)
        }
    }
}

private extension Data {
    nonisolated mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8))
        append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        append(data)
        append(Data("\r\n".utf8))
    }

    nonisolated mutating func appendMultipart(boundary: String, name: String, value: String) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        append(Data("\(value)\r\n".utf8))
    }
}
