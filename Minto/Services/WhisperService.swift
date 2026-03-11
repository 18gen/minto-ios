import Foundation

actor WhisperService {
    // swiftlint:disable:next force_unwrapping
    private let endpoint = URL(string: "\(AppSettings.apiProxyBase)/v1/whisper")!

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
        case httpError(Int, String)
        case decodingError(String)

        var errorDescription: String? {
            switch self {
            case let .httpError(code, msg): "HTTP \(code): \(msg)"
            case let .decodingError(msg): "Decoding error: \(msg)"
            }
        }
    }

    func transcribe(audioData: Data, languageCode: String = "ja") async throws -> VerboseResult {
        let boundary = UUID().uuidString
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendMultipartField(boundary: boundary, name: "file", filename: "audio.wav", mimeType: "audio/wav", data: audioData)
        body.appendMultipartField(boundary: boundary, name: "model", value: "whisper-1")
        body.appendMultipartField(boundary: boundary, name: "language", value: languageCode)
        body.appendMultipartField(boundary: boundary, name: "response_format", value: "verbose_json")
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