import Foundation

/// Shared PCM audio conversion utilities. Thread-safe, stateless.
enum AudioConversion {
    /// Convert Float32 samples to Int16 PCM packed as Data (for streaming to APIs).
    static func float32ToInt16PCM(_ samples: [Float]) -> Data {
        var data = Data(count: samples.count * 2)
        data.withUnsafeMutableBytes { rawBuffer in
            let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
            for i in samples.indices {
                let clamped = max(-1.0, min(1.0, samples[i]))
                int16Buffer[i] = Int16(clamped * Float(Int16.max))
            }
        }
        return data
    }
}
