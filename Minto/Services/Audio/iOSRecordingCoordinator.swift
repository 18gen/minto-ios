import AVFoundation
import Foundation
import Observation
import SwiftData
import UIKit

enum TranscriptionMode: String, CaseIterable {
    case elevenLabs // ElevenLabs Scribe v2 (best Japanese accuracy)
    case cloud // Deepgram Nova-3 (fallback)
    case onDevice // Whisper (offline fallback)
}

@Observable
@MainActor
final class iOSRecordingCoordinator {
    static let shared = iOSRecordingCoordinator()

    private let audioCaptureService = iOSAudioCaptureService()
    private let whisperService = WhisperService()
    private let deepgramService = DeepgramStreamingService()
    private let elevenLabsService = ElevenLabsStreamingService()
    private let elevenLabsBatchService = ElevenLabsBatchService()

    var isRecording = false
    var currentMeeting: Meeting?
    var recordingError: String?
    var transcriptionMode: TranscriptionMode = .elevenLabs

    var currentPartial: String = ""
    var currentAudioLevel: Float = 0.0

    var isProcessingBatch = false
    var batchProcessingStatus: String = ""

    private var committedText: String = ""
    private var recordingStartDate: Date = .now
    private var levelPollTimer: Timer?
    private let activityManager = RecordingActivityManager.shared
    private var lastActivityUpdateSecond: Int = -1
    private var activeMode: TranscriptionMode = .elevenLabs

    private let backgroundLock = NSLock()
    private var _isInBackground = false
    private var _backgroundAudioBuffer: [Data] = []
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    /// Resolves which transcription mode to use based on available keys.
    private func resolveTranscriptionMode() -> TranscriptionMode {
        if transcriptionMode == .elevenLabs, !AppSettings.elevenLabsKey.isEmpty {
            return .elevenLabs
        }
        // ElevenLabs key missing — fall back
        if transcriptionMode == .elevenLabs {
            if !AppSettings.deepgramKey.isEmpty { return .cloud }
            if !AppSettings.whisperKey.isEmpty { return .onDevice }
        }
        if transcriptionMode == .cloud, AppSettings.deepgramKey.isEmpty {
            return .onDevice
        }
        if transcriptionMode == .onDevice, AppSettings.whisperKey.isEmpty, !AppSettings.deepgramKey.isEmpty {
            return .cloud
        }
        return transcriptionMode
    }

    func startRecording(meeting: Meeting, modelContext _: ModelContext) async {
        recordingError = nil
        currentMeeting = meeting
        meeting.status = "recording"
        committedText = meeting.rawTranscript
        currentPartial = ""
        recordingStartDate = .now

        let effectiveMode = resolveTranscriptionMode()
        activeMode = effectiveMode

        // Validate we have at least one API key
        if effectiveMode == .onDevice, AppSettings.whisperKey.isEmpty {
            recordingError = "No API key configured. Add an ElevenLabs, Deepgram, or OpenAI key."
            meeting.status = "idle"
            return
        }

        // Request mic permission
        let granted: Bool = if #available(iOS 17.0, *) {
            await AVAudioApplication.requestRecordPermission()
        } else {
            await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { result in
                    continuation.resume(returning: result)
                }
            }
        }

        guard granted else {
            recordingError = "Microphone permission denied. Go to Settings > Privacy > Microphone."
            meeting.status = "idle"
            return
        }

        // Set up callbacks based on mode
        switch effectiveMode {
        case .elevenLabs:
            setupElevenLabsCallbacks()
            audioCaptureService.shouldAccumulateFullRecording = true
        case .cloud:
            setupDeepgramCallbacks()
            audioCaptureService.shouldAccumulateFullRecording = false
        case .onDevice:
            setupWhisperCallbacks()
            audioCaptureService.shouldAccumulateFullRecording = false
        }

        do {
            // Connect WebSocket before starting audio capture
            switch effectiveMode {
            case .elevenLabs:
                try elevenLabsService.connect()
            case .cloud:
                try deepgramService.connect()
            case .onDevice:
                break
            }

            try await audioCaptureService.startCapture()
            isRecording = true
            lastActivityUpdateSecond = -1
            activityManager.startActivity(title: meeting.title)

            startLevelPollTimer()

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self, self.isRecording else { return }
                if !self.audioCaptureService.hasReceivedNonSilence {
                    self.recordingError = "Listening for audio..."
                }
            }
        } catch {
            recordingError = "Failed to start: \(error.localizedDescription)"
            meeting.status = "idle"
            elevenLabsService.disconnect()
            deepgramService.disconnect()
        }
    }

    func stopRecording() async {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
        currentAudioLevel = 0.0

        elevenLabsService.disconnect()
        deepgramService.disconnect()
        audioCaptureService.onRawPCMReady = nil
        audioCaptureService.onAudioChunkReady = nil

        // Clean up background state
        backgroundLock.withLock {
            _isInBackground = false
            _backgroundAudioBuffer = []
        }
        endBackgroundTask()

        // Save full recording before stopping capture (samples cleared on stop)
        var savedAudioURL: URL?
        if activeMode == .elevenLabs {
            savedAudioURL = audioCaptureService.saveFullRecording()
        }

        await audioCaptureService.stopCapture()

        currentPartial = ""
        isRecording = false
        currentMeeting?.endDate = .now

        activityManager.endActivity()

        // If ElevenLabs mode, run batch diarization + LLM pipeline
        if activeMode == .elevenLabs, let meeting = currentMeeting, let audioURL = savedAudioURL {
            meeting.status = "processing"
            Task { @MainActor [weak self] in
                await self?.runPostRecordingPipeline(meeting: meeting, audioURL: audioURL)
            }
        } else {
            currentMeeting?.status = "done"
            currentMeeting = nil
            committedText = ""
        }
    }

    // MARK: - Level Poll Timer

    private func startLevelPollTimer() {
        levelPollTimer?.invalidate()
        levelPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentAudioLevel = self.audioCaptureService.currentAudioLevel
                if self.recordingError != nil, self.audioCaptureService.hasReceivedNonSilence {
                    self.recordingError = nil
                }

                // Update Live Activity once per second
                let elapsed = Int(Date.now.timeIntervalSince(self.recordingStartDate))
                if elapsed != self.lastActivityUpdateSecond {
                    self.lastActivityUpdateSecond = elapsed
                    self.activityManager.updateActivity(elapsedSeconds: elapsed, isPaused: false)
                }
            }
        }
    }

    // MARK: - Background / Foreground

    func handleAppBackgrounded() {
        guard isRecording else { return }

        backgroundLock.withLock { _isInBackground = true }

        // Disconnect WebSocket — iOS suspends it in background anyway
        switch activeMode {
        case .elevenLabs:
            elevenLabsService.disconnect()
        case .cloud:
            deepgramService.disconnect()
        case .onDevice:
            break
        }

        // Stop level poll timer (won't fire in background)
        levelPollTimer?.invalidate()
        levelPollTimer = nil

        // Request extra time for clean disconnect
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor [weak self] in
                self?.endBackgroundTask()
            }
        }
    }

    func handleAppForegrounded() {
        guard isRecording else { return }

        endBackgroundTask()

        // Reconnect WebSocket
        do {
            switch activeMode {
            case .elevenLabs:
                try elevenLabsService.connect()
            case .cloud:
                try deepgramService.connect()
            case .onDevice:
                break
            }
        } catch {
            recordingError = "Reconnect failed: \(error.localizedDescription)"
        }

        // Atomically drain buffer and switch to foreground mode
        let buffered = backgroundLock.withLock {
            let buf = _backgroundAudioBuffer
            _backgroundAudioBuffer = []
            _isInBackground = false
            return buf
        }

        // Flush buffered audio to the reconnected WebSocket
        for chunk in buffered {
            switch activeMode {
            case .elevenLabs:
                elevenLabsService.sendAudio(chunk)
            case .cloud:
                deepgramService.sendAudio(chunk)
            case .onDevice:
                break
            }
        }

        // Restart level poll timer and audio level display
        startLevelPollTimer()
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - ElevenLabs (Realtime) Setup

    private func setupElevenLabsCallbacks() {
        // Stream raw PCM to ElevenLabs (base64-encoded internally)
        // When backgrounded, buffer locally instead of streaming
        audioCaptureService.onRawPCMReady = { [weak self] pcmData in
            guard let self else { return }
            let inBackground = self.backgroundLock.withLock { self._isInBackground }
            if inBackground {
                self.backgroundLock.withLock { self._backgroundAudioBuffer.append(pcmData) }
            } else {
                self.elevenLabsService.sendAudio(pcmData)
            }
        }

        // Don't use WAV chunk callback in streaming mode
        audioCaptureService.onAudioChunkReady = nil

        // Receive transcripts from ElevenLabs
        elevenLabsService.onTranscript = { [weak self] result in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleElevenLabsResult(result)
            }
        }

        elevenLabsService.onError = { [weak self] error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.recordingError = "ElevenLabs: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func handleElevenLabsResult(_ result: ElevenLabsStreamingService.TranscriptResult) {
        guard let meeting = currentMeeting else { return }

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if !result.isFinal {
            currentPartial = text
            return
        }

        // Final result — commit
        currentPartial = ""

        if !committedText.isEmpty {
            committedText += "\n"
        }
        committedText += text
        meeting.rawTranscript = committedText

        // No speaker diarization in realtime mode — append as single segment
        let startTime = result.words.first?.start ?? 0
        let endTime = result.words.last?.end ?? startTime

        if let lastSegment = meeting.segments.last, lastSegment.source == "microphone", lastSegment.speaker == nil {
            lastSegment.text += "\n" + text
            lastSegment.endTime = endTime
        } else {
            let segment = TranscriptSegment(
                text: text,
                startTime: startTime,
                endTime: endTime,
                source: "microphone"
            )
            meeting.segments.append(segment)
        }
    }

    // MARK: - Post-Recording Pipeline (Batch Diarization + LLM)

    @MainActor
    private func runPostRecordingPipeline(meeting: Meeting, audioURL: URL) async {
        isProcessingBatch = true

        // Step 1: Batch transcription with speaker diarization
        batchProcessingStatus = "Analyzing speakers..."
        do {
            let result = try await elevenLabsBatchService.transcribe(audioFileURL: audioURL)

            // Replace realtime segments with diarized version
            meeting.segments.removeAll()
            for utterance in result.utterances {
                let segment = TranscriptSegment(
                    text: utterance.text,
                    startTime: utterance.start,
                    endTime: utterance.end,
                    source: "microphone",
                    speaker: parseSpeakerIndex(utterance.speakerId)
                )
                meeting.segments.append(segment)
            }
            meeting.rawTranscript = result.text
            committedText = result.text
        } catch {
            // Keep realtime transcript on batch failure
            print("Batch transcription failed: \(error.localizedDescription)")
        }

        // Step 2: LLM transcript correction
        if !AppSettings.claudeKey.isEmpty {
            batchProcessingStatus = "Polishing transcript..."
            do {
                let corrected = try await ClaudeService.shared.correctTranscript(
                    rawTranscript: meeting.rawTranscript
                )
                meeting.rawTranscript = corrected
                committedText = corrected
            } catch {
                // Keep uncorrected transcript on LLM failure
                print("LLM correction failed: \(error.localizedDescription)")
            }
        }

        // Clean up saved audio file
        try? FileManager.default.removeItem(at: audioURL)

        meeting.status = "done"
        isProcessingBatch = false
        batchProcessingStatus = ""
        currentMeeting = nil
        committedText = ""
    }

    private func parseSpeakerIndex(_ speakerId: String) -> Int {
        // ElevenLabs returns "speaker_0", "speaker_1", etc.
        if let lastComponent = speakerId.split(separator: "_").last,
           let index = Int(lastComponent)
        {
            return index
        }
        return 0
    }

    // MARK: - Deepgram (Cloud) Setup

    private func setupDeepgramCallbacks() {
        // Stream raw PCM to Deepgram
        // When backgrounded, buffer locally instead of streaming
        audioCaptureService.onRawPCMReady = { [weak self] pcmData in
            guard let self else { return }
            let inBackground = self.backgroundLock.withLock { self._isInBackground }
            if inBackground {
                self.backgroundLock.withLock { self._backgroundAudioBuffer.append(pcmData) }
            } else {
                self.deepgramService.sendAudio(pcmData)
            }
        }

        // Don't use WAV chunk callback in cloud mode
        audioCaptureService.onAudioChunkReady = nil

        // Receive transcripts from Deepgram
        deepgramService.onTranscript = { [weak self] result in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleDeepgramResult(result)
            }
        }

        deepgramService.onError = { [weak self] error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.recordingError = "Deepgram: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func handleDeepgramResult(_ result: DeepgramStreamingService.TranscriptResult) {
        guard let meeting = currentMeeting else { return }

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if !result.isFinal {
            // Interim result — show as partial
            currentPartial = text
            return
        }

        // Final result — commit
        currentPartial = ""

        if !committedText.isEmpty {
            committedText += "\n"
        }
        committedText += text
        meeting.rawTranscript = committedText

        // Group words by speaker runs and create segments
        let speakerRuns = groupWordsBySpeaker(result.words)

        for run in speakerRuns {
            let runText = run.words.map(\.word).joined(separator: "")
            guard !runText.isEmpty else { continue }

            let startTime = run.words.first?.start ?? 0
            let endTime = run.words.last?.end ?? startTime

            // Merge with last segment if same speaker
            if let lastSegment = meeting.segments.last,
               lastSegment.speaker == run.speaker,
               lastSegment.source == "microphone"
            {
                lastSegment.text += runText
                lastSegment.endTime = endTime
            } else {
                let segment = TranscriptSegment(
                    text: runText,
                    startTime: startTime,
                    endTime: endTime,
                    source: "microphone",
                    speaker: run.speaker
                )
                meeting.segments.append(segment)
            }
        }
    }

    private struct SpeakerRun {
        let speaker: Int
        var words: [DeepgramStreamingService.Word]
    }

    private func groupWordsBySpeaker(_ words: [DeepgramStreamingService.Word]) -> [SpeakerRun] {
        guard let first = words.first else { return [] }

        var runs: [SpeakerRun] = [SpeakerRun(speaker: first.speaker, words: [first])]

        for word in words.dropFirst() {
            if word.speaker == runs[runs.count - 1].speaker {
                runs[runs.count - 1].words.append(word)
            } else {
                runs.append(SpeakerRun(speaker: word.speaker, words: [word]))
            }
        }

        return runs
    }

    // MARK: - Whisper (On-Device / Legacy) Setup

    private func setupWhisperCallbacks() {
        // Don't stream raw PCM in on-device mode
        audioCaptureService.onRawPCMReady = nil

        audioCaptureService.onAudioChunkReady = { [weak self] wavData in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.currentPartial = "..."
            }
            Task {
                await self.transcribeChunk(wavData)
            }
        }
    }

    // MARK: - Whisper Micro-Batch

    private nonisolated static let whisperHallucinations: Set<String> = [
        "ご清聴ありがとうございました。",
        "ご清聴ありがとうございました",
        "ご視聴ありがとうございました。",
        "ご視聴ありがとうございました",
        "お疲れ様でした。",
        "お疲れ様でした",
        "ありがとうございました。",
        "ありがとうございました",
        "Thank you.",
        "Thank you for watching.",
        "Thanks for watching.",
        "Thank you for listening.",
        "Bye.",
        "Bye bye.",
        "...",
        "。",
    ]

    private nonisolated func transcribeChunk(_ wavData: Data) async {
        do {
            let result = try await whisperService.transcribe(audioData: wavData)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            if Self.whisperHallucinations.contains(text) {
                await MainActor.run { [weak self] in
                    self?.currentPartial = ""
                }
                return
            }

            await MainActor.run { [weak self] in
                guard let self, let meeting = self.currentMeeting else { return }

                let elapsedSeconds = Date.now.timeIntervalSince(self.recordingStartDate)

                if !self.committedText.isEmpty {
                    self.committedText += "\n"
                }
                self.committedText += text

                self.currentPartial = ""
                meeting.rawTranscript = self.committedText

                // All segments are microphone on iOS (no speaker diarization in Whisper mode)
                if let lastSegment = meeting.segments.last, lastSegment.source == "microphone" {
                    lastSegment.text += " " + text
                    lastSegment.endTime = elapsedSeconds
                } else {
                    let segment = TranscriptSegment(
                        text: text,
                        startTime: max(0, elapsedSeconds - 3),
                        endTime: elapsedSeconds,
                        source: "microphone"
                    )
                    meeting.segments.append(segment)
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.currentPartial = ""
                if case WhisperService.WhisperError.noAPIKey = error {
                    self?.recordingError = error.localizedDescription
                }
            }
        }
    }
}
