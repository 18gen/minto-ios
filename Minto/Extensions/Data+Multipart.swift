import Foundation

/// Shared multipart form-data helpers for HTTP uploads.
extension Data {
    nonisolated mutating func appendMultipartField(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8))
        append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        append(data)
        append(Data("\r\n".utf8))
    }

    nonisolated mutating func appendMultipartField(boundary: String, name: String, value: String) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        append(Data("\(value)\r\n".utf8))
    }
}
