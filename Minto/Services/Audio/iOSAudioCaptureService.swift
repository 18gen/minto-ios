import Foundation
import AVFoundation
import Accelerate

final class iOSAudioCaptureService: @unchecked Sendable {
    private let lock = NSLock()

    private var engine: AVAudioEngine?
    private var samples: [Float] = []
    private var chunkStartTime: Date = .now
    private let chunkDuration: TimeInterval = 3
    private let sampleRate: Double = 16000

    private let silenceThreshold: Float = 0.005

    private var _isCapturing = false
    var isCapturing: Bool {
        lock.withLock { _isCapturing }
    }

    var onAudioChunkReady: ((Data) -> Void)?

    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    private var cachedConverter: AVAudioConverter?

    private var _currentAudioLevel: Float = 0.0
    var currentAudioLevel: Float {
        lock.withLock { _currentAudioLevel }
    }

    private var _hasReceivedNonSilence = false
    var hasReceivedNonSilence: Bool {
        lock.withLock { _hasReceivedNonSilence }
    }

    func startCapture() async throws {
        lock.withLock {
            _hasReceivedNonSilence = false
            _currentAudioLevel = 0.0
            samples = []
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw CaptureError.noMicrophone
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            if let converted = self.convertBuffer(buffer) {
                let frameCount = Int(converted.frameLength)
                if frameCount > 0, let ptr = converted.floatChannelData?[0] {
                    let samplesArray = Array(UnsafeBufferPointer(start: ptr, count: frameCount))

                    var rms: Float = 0.0
                    vDSP_rmsqv(ptr, 1, &rms, vDSP_Length(frameCount))
                    let normalizedLevel = min(rms * 3.0, 1.0)

                    self.lock.withLock {
                        self._currentAudioLevel = normalizedLevel
                        if !self._hasReceivedNonSilence && rms > 0.0001 {
                            self._hasReceivedNonSilence = true
                        }
                    }

                    self.accumulateSamples(samplesArray)
                }
            }
        }

        try engine.start()
        lock.withLock {
            self.engine = engine
            _isCapturing = true
            chunkStartTime = .now
        }
    }

    func stopCapture() async {
        let eng = lock.withLock {
            let e = engine
            engine = nil
            return e
        }
        eng?.inputNode.removeTap(onBus: 0)
        eng?.stop()

        let remaining = lock.withLock {
            let s = samples
            samples = []
            _isCapturing = false
            _currentAudioLevel = 0.0
            _hasReceivedNonSilence = false
            cachedConverter = nil
            return s
        }

        if !remaining.isEmpty, let wavData = createWAV(from: remaining) {
            onAudioChunkReady?(wavData)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Sample Accumulation

    private func accumulateSamples(_ newSamples: [Float]) {
        let (shouldFlush, chunk) = lock.withLock {
            samples.append(contentsOf: newSamples)
            let elapsed = Date.now.timeIntervalSince(chunkStartTime)
            if elapsed >= chunkDuration {
                let s = samples
                samples = []
                chunkStartTime = .now
                return (true, s)
            }
            return (false, [Float]())
        }

        if shouldFlush, !chunk.isEmpty, let wavData = createWAV(from: chunk) {
            onAudioChunkReady?(wavData)
        }
    }

    // MARK: - WAV Creation

    private func createWAV(from samples: [Float]) -> Data? {
        guard !samples.isEmpty else { return nil }

        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        if rms < silenceThreshold { return nil }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
                return nil
            }
            outputBuffer.frameLength = AVAudioFrameCount(samples.count)
            let dst = outputBuffer.floatChannelData![0]
            samples.withUnsafeBufferPointer { src in
                dst.update(from: src.baseAddress!, count: samples.count)
            }

            let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try file.write(from: outputBuffer)
            return try Data(contentsOf: tempURL)
        } catch {
            return nil
        }
    }

    // MARK: - Audio Conversion

    private func convertBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard buffer.frameLength > 0 else { return nil }

        let converter: AVAudioConverter
        if let cached = lock.withLock({ cachedConverter }), cached.inputFormat == buffer.format {
            converter = cached
        } else {
            guard let newConverter = AVAudioConverter(from: buffer.format, to: targetFormat) else { return nil }
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

    enum CaptureError: LocalizedError {
        case noMicrophone

        var errorDescription: String? {
            switch self {
            case .noMicrophone: return "No microphone available"
            }
        }
    }
}
