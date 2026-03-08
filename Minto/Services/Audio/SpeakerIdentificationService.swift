import Eagle
import Foundation

/// Wraps Picovoice Eagle for real-time speaker identification during recording.
/// Compares incoming audio frames against enrolled speaker profiles.
final class SpeakerIdentificationService: @unchecked Sendable {
    private let lock = NSLock()

    private var eagle: Eagle?
    private var frameBuffer: [Int16] = []
    private var requiredFrameLength: Int = 0

    private var _isActive = false
    var isActive: Bool { lock.withLock { _isActive } }

    /// Confidence threshold — scores above this mean "it's this speaker".
    var confidenceThreshold: Float = 0.5

    /// Called on the audio thread with the index of the identified speaker and confidence.
    /// Index 0 = the user's enrolled profile (since we only enroll "me" for now).
    /// Score < threshold means unknown speaker.
    var onSpeakerIdentified: ((_ speakerIndex: Int?, _ scores: [Float]) -> Void)?

    /// Initialize Eagle with the enrolled speaker profiles.
    /// - Parameter profileDataList: Array of serialized EagleProfile bytes (from SpeakerProfile.profileData).
    func initialize(profileDataList: [Data]) throws {
        let key = AppSettings.picovoiceKey
        guard !key.isEmpty else {
            throw IdentificationError.noAccessKey
        }
        guard !profileDataList.isEmpty else {
            throw IdentificationError.noProfiles
        }

        let profiles = profileDataList.map { data in
            EagleProfile(profileBytes: [UInt8](data))
        }

        let e = try Eagle(accessKey: key, speakerProfiles: profiles)
        requiredFrameLength = Eagle.frameLength

        lock.withLock {
            eagle = e
            frameBuffer = []
            _isActive = true
        }
    }

    /// Feed raw Int16 PCM data (from iOSAudioCaptureService.onRawPCMReady converted to [Int16]).
    /// Buffers until we have `Eagle.frameLength` samples, then processes.
    func processAudio(_ pcmData: Data) {
        guard lock.withLock({ _isActive && eagle != nil }) else { return }

        // Convert Data to [Int16]
        let int16Count = pcmData.count / 2
        var int16Samples = [Int16](repeating: 0, count: int16Count)
        pcmData.withUnsafeBytes { rawBuffer in
            let src = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<int16Count {
                int16Samples[i] = src[i]
            }
        }

        lock.withLock { frameBuffer.append(contentsOf: int16Samples) }

        // Process complete frames
        while true {
            let (frame, eagleRef) = lock.withLock { () -> ([Int16], Eagle?) in
                guard frameBuffer.count >= requiredFrameLength else { return ([], nil) }
                let frame = Array(frameBuffer.prefix(requiredFrameLength))
                frameBuffer.removeFirst(requiredFrameLength)
                return (frame, eagle)
            }

            guard !frame.isEmpty, let eagleRef else { break }

            do {
                let scores = try eagleRef.process(pcm: frame)

                // Find best scoring speaker above threshold
                var bestIndex: Int?
                var bestScore: Float = confidenceThreshold
                for (index, score) in scores.enumerated() {
                    if score > bestScore {
                        bestScore = score
                        bestIndex = index
                    }
                }

                onSpeakerIdentified?(bestIndex, scores)
            } catch {
                // Process error — skip frame
            }
        }
    }

    /// Reset Eagle's internal state (call between voice interactions).
    func reset() {
        lock.withLock {
            try? eagle?.reset()
            frameBuffer = []
        }
    }

    /// Stop identification and release resources.
    func stop() {
        lock.withLock {
            eagle?.delete()
            eagle = nil
            frameBuffer = []
            _isActive = false
        }
        onSpeakerIdentified = nil
    }

    // MARK: - Errors

    enum IdentificationError: LocalizedError {
        case noAccessKey
        case noProfiles

        var errorDescription: String? {
            switch self {
            case .noAccessKey: "Picovoice access key not configured."
            case .noProfiles: "No speaker profiles enrolled."
            }
        }
    }
}
