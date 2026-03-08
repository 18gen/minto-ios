import AVFoundation
import Eagle
import Foundation

/// Wraps Picovoice EagleProfiler for speaker voice enrollment.
/// Records audio from the microphone and progressively enrolls the user's voice.
final class VoiceEnrollmentService: @unchecked Sendable {
    private let lock = NSLock()

    private var profiler: EagleProfiler?
    private var engine: AVAudioEngine?
    private var minSamples: Int = 0

    private var _isEnrolling = false
    var isEnrolling: Bool { lock.withLock { _isEnrolling } }

    private var _enrollmentPercentage: Float = 0
    var enrollmentPercentage: Float { lock.withLock { _enrollmentPercentage } }

    private var _lastFeedback: EagleProfilerEnrollFeedback = .AUDIO_OK

    /// Human-readable feedback message for the UI (avoids leaking Eagle types).
    var feedbackMessage: String {
        switch lock.withLock({ _lastFeedback }) {
        case .AUDIO_OK: return ""
        case .AUDIO_TOO_SHORT: return "Keep speaking a bit longer..."
        case .UNKNOWN_SPEAKER: return "Multiple voices detected. Please speak alone."
        case .NO_VOICE_FOUND: return "No voice detected. Speak closer to the mic."
        case .QUALITY_ISSUE: return "Audio quality issue. Try a quieter environment."
        }
    }

    private var _audioLevel: Float = 0
    var audioLevel: Float { lock.withLock { _audioLevel } }

    /// Accumulated Int16 PCM samples awaiting enrollment
    private var sampleBuffer: [Int16] = []

    // swiftlint:disable:next force_unwrapping
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    private var cachedConverter: AVAudioConverter?

    /// Initialize the profiler with the Picovoice access key.
    func initialize() throws {
        let key = AppSettings.picovoiceKey
        guard !key.isEmpty else {
            throw EnrollmentError.noAccessKey
        }

        let p = try EagleProfiler(accessKey: key)
        minSamples = try p.minEnrollSamples()
        lock.withLock { profiler = p }
    }

    /// Start capturing audio and enrolling the speaker.
    func startEnrollment() async throws {
        guard let profiler = lock.withLock({ profiler }) else {
            throw EnrollmentError.notInitialized
        }

        try profiler.reset()
        lock.withLock {
            _enrollmentPercentage = 0
            _lastFeedback = .AUDIO_OK
            sampleBuffer = []
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw EnrollmentError.noMicrophone
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let converted = self.convertBuffer(buffer, inputFormat: inputFormat) else { return }
            let frameCount = Int(converted.frameLength)
            guard frameCount > 0, let ptr = converted.floatChannelData?[0] else { return }

            // Convert Float32 to Int16
            var int16Samples = [Int16](repeating: 0, count: frameCount)
            for i in 0..<frameCount {
                let clamped = max(-1.0, min(1.0, ptr[i]))
                int16Samples[i] = Int16(clamped * Float(Int16.max))
            }

            // Calculate audio level for UI
            var rms: Float = 0
            for sample in int16Samples {
                rms += Float(sample) * Float(sample)
            }
            rms = sqrt(rms / Float(int16Samples.count)) / Float(Int16.max)

            self.lock.withLock {
                self._audioLevel = min(rms * 3.0, 1.0)
                self.sampleBuffer.append(contentsOf: int16Samples)
            }

            self.processBufferedSamples()
        }

        try engine.start()
        lock.withLock {
            self.engine = engine
            _isEnrolling = true
        }
    }

    /// Process buffered samples through the profiler when we have enough.
    private func processBufferedSamples() {
        let (samplesToProcess, profilerRef) = lock.withLock { () -> ([Int16], EagleProfiler?) in
            guard sampleBuffer.count >= minSamples else { return ([], nil) }
            let samples = sampleBuffer
            sampleBuffer = []
            return (samples, profiler)
        }

        guard !samplesToProcess.isEmpty, let profilerRef else { return }

        do {
            let (percentage, feedback) = try profilerRef.enroll(pcm: samplesToProcess)
            lock.withLock {
                _enrollmentPercentage = percentage
                _lastFeedback = feedback
            }
        } catch {
            // Enrollment error — keep collecting
        }
    }

    /// Export the enrolled profile bytes. Call after enrollment reaches 100%.
    func exportProfile() throws -> Data {
        guard let profiler = lock.withLock({ profiler }) else {
            throw EnrollmentError.notInitialized
        }

        let eagleProfile = try profiler.export()
        let bytes = eagleProfile.getBytes()
        return Data(bytes)
    }

    /// Stop enrollment and release audio resources.
    func stopEnrollment() {
        let eng = lock.withLock {
            let e = engine
            engine = nil
            _isEnrolling = false
            _audioLevel = 0
            cachedConverter = nil
            return e
        }
        eng?.inputNode.removeTap(onBus: 0)
        eng?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Release all resources including the profiler.
    func cleanup() {
        stopEnrollment()
        lock.withLock {
            profiler?.delete()
            profiler = nil
        }
    }

    // MARK: - Audio Conversion

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.frameLength > 0 else { return nil }

        let converter: AVAudioConverter
        if let cached = lock.withLock({ cachedConverter }), cached.inputFormat == buffer.format {
            converter = cached
        } else {
            guard let newConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else { return nil }
            lock.withLock { cachedConverter = newConverter }
            converter = newConverter
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0 else { return nil }
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else { return nil }

        var error: NSError?
        var hasData = true
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .haveData
                hasData = false
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if error != nil { return nil }
        return outputBuffer
    }

    // MARK: - Errors

    enum EnrollmentError: LocalizedError {
        case noAccessKey
        case notInitialized
        case noMicrophone

        var errorDescription: String? {
            switch self {
            case .noAccessKey: "Picovoice access key not configured. Add PICOVOICE_ACCESS_KEY."
            case .notInitialized: "Voice enrollment service not initialized."
            case .noMicrophone: "No microphone available."
            }
        }
    }
}
