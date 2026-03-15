import Accelerate
import AVFoundation
import Foundation
import os.log

final class iOSAudioCaptureService: @unchecked Sendable {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Minto", category: "AudioCapture")
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

    /// Fires on every audio tap (~100ms) with raw Int16 PCM bytes for streaming to Deepgram.
    var onRawPCMReady: ((Data) -> Void)?

    // swiftlint:disable:next force_unwrapping - guaranteed valid for standard PCM format
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    private var cachedConverter: AVAudioConverter?
    private var interruptionObserver: Any?
    private var routeChangeObserver: Any?

    private var fullRecordingSamples: [Float] = []
    private var _shouldAccumulateFullRecording = false

    var shouldAccumulateFullRecording: Bool {
        get { lock.withLock { _shouldAccumulateFullRecording } }
        set { lock.withLock { _shouldAccumulateFullRecording = newValue } }
    }

    private var _currentAudioLevel: Float = 0.0
    var currentAudioLevel: Float {
        lock.withLock { _currentAudioLevel }
    }

    private var _hasReceivedNonSilence = false
    var hasReceivedNonSilence: Bool {
        lock.withLock { _hasReceivedNonSilence }
    }

    private var _isReinstallingTap = false

    /// Timestamped RMS energy samples for speaker identification.
    /// Each entry: (seconds since capture start, raw RMS value).
    private var _energyLog: [(elapsed: TimeInterval, rms: Float)] = []
    private var captureStartDate: Date = .now

    func startCapture() async throws {
        lock.withLock {
            _hasReceivedNonSilence = false
            _currentAudioLevel = 0.0
            samples = []
            fullRecordingSamples = []
            _energyLog = []
        }
        captureStartDate = .now

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [
            .mixWithOthers, .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP,
            .overrideMutedMicrophoneInterruption,
        ])

        // Session activation can fail when another app (e.g. VoIP call) owns the audio session.
        // Retry once after a brief pause, then attempt engine start regardless.
        do {
            try session.setActive(true)
        } catch {
            Self.log.warning("setActive failed, retrying: \(error.localizedDescription)")
            try? await Task.sleep(for: .milliseconds(300))
            do {
                try session.setActive(true)
            } catch {
                Self.log.warning("setActive retry failed, attempting engine start anyway: \(error.localizedDescription)")
            }
        }

        let engine = AVAudioEngine()
        let inputFormat = installTap(on: engine)

        guard let inputFormat else {
            throw CaptureError.noMicrophone
        }

        Self.log.info("Capture started — input: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")
        Self.logCurrentRoute()

        try engine.start()
        lock.withLock {
            self.engine = engine
            _isCapturing = true
            chunkStartTime = .now
        }

        // Listen for audio session interruptions (e.g. phone call)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        // Listen for audio route changes (e.g. Bluetooth disconnect)
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    // MARK: - Tap Installation

    /// Installs an audio tap on the engine's input node. Returns the input format, or nil if no mic.
    @discardableResult
    private func installTap(on engine: AVAudioEngine) -> AVAudioFormat? {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            return nil
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

                    let elapsed = Date.now.timeIntervalSince(self.captureStartDate)
                    self.lock.withLock {
                        self._currentAudioLevel = normalizedLevel
                        if !self._hasReceivedNonSilence, rms > 0.0001 {
                            self._hasReceivedNonSilence = true
                        }
                        self._energyLog.append((elapsed, rms))
                    }

                    // Stream raw Int16 PCM for Deepgram / ElevenLabs
                    if let pcmCallback = self.onRawPCMReady {
                        let int16Data = Self.float32ToInt16PCM(samplesArray)
                        pcmCallback(int16Data)
                    }

                    if self.lock.withLock({ self._shouldAccumulateFullRecording }) {
                        self.lock.withLock {
                            self.fullRecordingSamples.append(contentsOf: samplesArray)
                        }
                    }

                    self.accumulateSamples(samplesArray)
                }
            }
        }

        return inputFormat
    }

    /// Stops engine, removes tap, invalidates converter, reinstalls tap with new format, restarts.
    /// Safe to call from any thread. Guarded against concurrent execution.
    private func reinstallTap() {
        let shouldProceed = lock.withLock {
            guard !_isReinstallingTap else { return false }
            _isReinstallingTap = true
            return true
        }
        guard shouldProceed else { return }
        defer { lock.withLock { _isReinstallingTap = false } }

        let eng = lock.withLock { engine }
        guard let eng else { return }

        eng.stop()
        eng.inputNode.removeTap(onBus: 0)
        lock.withLock { cachedConverter = nil }

        try? AVAudioSession.sharedInstance().setActive(true)
        installTap(on: eng)
        Self.logCurrentRoute()

        do {
            try eng.start()
        } catch {
            Self.log.error("Failed to restart engine after route change: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Event Handling

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            Self.log.info("Audio session interrupted")

        case .ended:
            Self.log.info("Audio session interruption ended — restarting")
            let eng = lock.withLock { engine }
            guard let eng else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            try? eng.start()

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .newDeviceAvailable:
            Self.log.info("Audio route: new device available — reinstalling tap")
            reinstallTap()
        case .oldDeviceUnavailable:
            Self.log.info("Audio route: device removed — reinstalling tap")
            reinstallTap()
        default:
            break
        }
    }

    // MARK: - Route Logging

    private static func logCurrentRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        let inputs = route.inputs.map { "\($0.portName) (\($0.portType.rawValue))" }.joined(separator: ", ")
        let outputs = route.outputs.map { "\($0.portName) (\($0.portType.rawValue))" }.joined(separator: ", ")
        log.info("Audio route — in: [\(inputs)] out: [\(outputs)]")
    }

    // MARK: - Energy Log (Speaker Identification)

    /// Returns the average RMS energy during a time range (seconds since capture start).
    /// Used to identify the user speaker (closest to mic = highest energy).
    func averageEnergy(from startTime: TimeInterval, to endTime: TimeInterval) -> Float {
        lock.withLock {
            let matching = _energyLog.filter { $0.elapsed >= startTime && $0.elapsed <= endTime }
            guard !matching.isEmpty else { return 0 }
            return matching.map(\.rms).reduce(0, +) / Float(matching.count)
        }
    }

    /// Clears the energy log after speaker identification is complete.
    func clearEnergyLog() {
        lock.withLock { _energyLog = [] }
    }

    func stopCapture() async {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }

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
            // Note: fullRecordingSamples is NOT cleared here —
            // coordinator calls saveFullRecording() before stopCapture()
            return s
        }

        if !remaining.isEmpty, let wavData = createWAV(from: remaining) {
            onAudioChunkReady?(wavData)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Full Recording Save

    /// Saves all accumulated audio to a persistent WAV file and returns its URL.
    /// Call this before `stopCapture()` when batch processing is needed.
    func saveFullRecording() -> URL? {
        let samples = lock.withLock {
            let s = fullRecordingSamples
            fullRecordingSamples = []
            return s
        }
        guard !samples.isEmpty else { return nil }

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return nil
        }

        let audioDir = documentsDir.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        let fileURL = audioDir.appendingPathComponent("\(UUID().uuidString).wav")

        do {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
                return nil
            }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            guard let dst = buffer.floatChannelData?[0] else { return nil }
            samples.withUnsafeBufferPointer { src in
                guard let baseAddr = src.baseAddress else { return }
                dst.update(from: baseAddr, count: samples.count)
            }

            let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try file.write(from: buffer)
            return fileURL
        } catch {
            return nil
        }
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

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
                return nil
            }
            outputBuffer.frameLength = AVAudioFrameCount(samples.count)
            guard let dst = outputBuffer.floatChannelData?[0] else { return nil }
            samples.withUnsafeBufferPointer { src in
                guard let baseAddr = src.baseAddress else { return }
                dst.update(from: baseAddr, count: samples.count)
            }

            let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try file.write(from: outputBuffer)
            return try Data(contentsOf: tempURL)
        } catch {
            return nil
        }
    }

    // MARK: - Float32 → Int16 PCM

    static func float32ToInt16PCM(_ samples: [Float]) -> Data {
        AudioConversion.float32ToInt16PCM(samples)
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
            case .noMicrophone: "No microphone available"
            }
        }
    }
}
