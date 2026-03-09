import AVFoundation
import Foundation
import Observation
import SwiftData

enum TranscriptionMode: String, CaseIterable {
    case elevenLabs // ElevenLabs Scribe v2 (best Japanese accuracy)
    case deepgram // Deepgram Nova-3
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
    private let speakerIdService = SpeakerIdentificationService()
    private let postRecordingProcessor = PostRecordingProcessor()
    private let backgroundManager = BackgroundAudioManager()

    var isRecording = false
    var currentMeeting: Meeting?
    var recordingError: String?
    var transcriptionMode: TranscriptionMode = .elevenLabs

    var currentPartial: String = ""
    var currentAudioLevel: Float = 0.0

    var isProcessingBatch: Bool { postRecordingProcessor.isProcessing }
    var batchProcessingStatus: String { postRecordingProcessor.statusMessage }

    private var committedText: String = ""
    private var recordingStartDate: Date = .now
    private var levelPollTimer: Timer?
    private let activityManager = RecordingActivityManager.shared
    private var activeMode: TranscriptionMode = .elevenLabs

    /// Total seconds accumulated from previous recording segments (before current active segment)
    private var accumulatedRecordingSeconds: TimeInterval = 0
    /// Wall-clock time when the current active segment started
    private var currentSegmentStartDate: Date = .now

    /// Total elapsed recording time (accumulated + current segment)
    var totalElapsedSeconds: TimeInterval {
        if isRecording {
            return accumulatedRecordingSeconds + Date.now.timeIntervalSince(currentSegmentStartDate)
        } else {
            return accumulatedRecordingSeconds
        }
    }

    private init() {}

    /// Resolves which transcription mode to use based on available keys.
    private func resolveTranscriptionMode() -> TranscriptionMode {
        if transcriptionMode == .elevenLabs, !AppSettings.elevenLabsKey.isEmpty {
            return .elevenLabs
        }
        // ElevenLabs key missing — fall back
        if transcriptionMode == .elevenLabs {
            if !AppSettings.deepgramKey.isEmpty { return .deepgram }
            if !AppSettings.whisperKey.isEmpty { return .onDevice }
        }
        if transcriptionMode == .deepgram, AppSettings.deepgramKey.isEmpty {
            return .onDevice
        }
        if transcriptionMode == .onDevice, AppSettings.whisperKey.isEmpty, !AppSettings.deepgramKey.isEmpty {
            return .deepgram
        }
        return transcriptionMode
    }

    func startRecording(meeting: Meeting, modelContext: ModelContext) async {
        recordingError = nil

        let isResume = currentMeeting === meeting && accumulatedRecordingSeconds > 0
        currentMeeting = meeting
        meeting.status = "recording"
        currentPartial = ""
        currentSegmentStartDate = .now

        if isResume {
            // Keep accumulated time and committed text
        } else {
            accumulatedRecordingSeconds = 0
            committedText = meeting.rawTranscript
            recordingStartDate = .now
        }

        // Initialize Eagle speaker identification if profiles exist
        initializeSpeakerIdentification(modelContext: modelContext, meeting: meeting)

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
        case .deepgram:
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
            case .deepgram:
                try deepgramService.connect()
            case .onDevice:
                break
            }

            try await audioCaptureService.startCapture()
            isRecording = true

            let syntheticStart = Date.now - accumulatedRecordingSeconds
            if isResume {
                activityManager.updateActivity(isPaused: false, startDate: syntheticStart, accumulatedSeconds: Int(accumulatedRecordingSeconds))
            } else {
                activityManager.startActivity(title: meeting.title, startDate: syntheticStart)
            }

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

    // MARK: - Eagle Speaker Identification

    private func initializeSpeakerIdentification(modelContext: ModelContext, meeting: Meeting) {
        guard !AppSettings.picovoiceKey.isEmpty else { return }

        let descriptor = FetchDescriptor<SpeakerProfile>(
            predicate: #Predicate { $0.enrollmentPercentage >= 100 }
        )
        guard let profiles = try? modelContext.fetch(descriptor), !profiles.isEmpty else { return }

        do {
            let profileDataList = profiles.map(\.profileData)
            try speakerIdService.initialize(profileDataList: profileDataList)

            // When Eagle identifies the user, mark it on the meeting
            speakerIdService.onSpeakerIdentified = { [weak self] speakerIndex, _ in
                guard let self, speakerIndex == 0 else { return }
                // Speaker index 0 = first enrolled profile = "me"
                Task { @MainActor [weak self] in
                    guard let self, let meeting = self.currentMeeting else { return }
                    if meeting.userSpeakerIndex == nil, let lastSegment = meeting.segments.last {
                        // Auto-mark the diarization speaker as "me"
                        if let speaker = lastSegment.speaker {
                            meeting.markSpeakerAsUser(speaker)
                        }
                    }
                }
            }
        } catch {
            // Eagle init failed — continue without speaker identification
        }
    }

    /// Pause recording — keeps accumulated time, updates Live Activity to paused state.
    func pauseRecording() async {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
        currentAudioLevel = 0.0

        elevenLabsService.disconnect()
        deepgramService.disconnect()
        speakerIdService.stop()
        audioCaptureService.onRawPCMReady = nil
        audioCaptureService.onAudioChunkReady = nil

        await audioCaptureService.stopCapture()

        // Accumulate elapsed time from this segment
        accumulatedRecordingSeconds += Date.now.timeIntervalSince(currentSegmentStartDate)

        currentPartial = ""
        isRecording = false

        activityManager.updateActivity(isPaused: true, startDate: .now, accumulatedSeconds: Int(accumulatedRecordingSeconds))
    }

    /// Fully stop recording — ends session and Live Activity.
    func stopRecording() async {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
        currentAudioLevel = 0.0

        elevenLabsService.disconnect()
        deepgramService.disconnect()
        speakerIdService.stop()
        audioCaptureService.onRawPCMReady = nil
        audioCaptureService.onAudioChunkReady = nil

        backgroundManager.reset()

        // Save full recording before stopping capture (samples cleared on stop)
        var savedAudioURL: URL?
        if activeMode == .elevenLabs {
            savedAudioURL = audioCaptureService.saveFullRecording()
        }

        await audioCaptureService.stopCapture()

        currentPartial = ""
        isRecording = false
        currentMeeting?.endDate = .now
        accumulatedRecordingSeconds = 0

        activityManager.endActivity()

        // If ElevenLabs mode, run batch diarization + LLM pipeline
        if activeMode == .elevenLabs, let meeting = currentMeeting, let audioURL = savedAudioURL {
            meeting.status = "processing"
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result = await self.postRecordingProcessor.process(meeting: meeting, audioURL: audioURL) {
                    self.applyPostRecordingResult(result, to: meeting)
                }
                meeting.status = "done"
                self.currentMeeting = nil
                self.committedText = ""
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
            }
        }
    }

    // MARK: - Background / Foreground

    func handleAppBackgrounded() {
        guard isRecording else { return }

        let mode = activeMode
        backgroundManager.enterBackground {
            switch mode {
            case .elevenLabs: self.elevenLabsService.disconnect()
            case .deepgram: self.deepgramService.disconnect()
            case .onDevice: break
            }
        }

        levelPollTimer?.invalidate()
        levelPollTimer = nil
    }

    func handleAppForegrounded() {
        guard isRecording else { return }

        // Reconnect WebSocket
        do {
            switch activeMode {
            case .elevenLabs: try elevenLabsService.connect()
            case .deepgram: try deepgramService.connect()
            case .onDevice: break
            }
        } catch {
            recordingError = "Reconnect failed: \(error.localizedDescription)"
        }

        // Drain buffered audio and flush to reconnected stream
        let buffered = backgroundManager.enterForeground()
        for chunk in buffered {
            switch activeMode {
            case .elevenLabs: elevenLabsService.sendAudio(chunk)
            case .deepgram: deepgramService.sendAudio(chunk)
            case .onDevice: break
            }
        }

        startLevelPollTimer()
    }

    // MARK: - ElevenLabs (Realtime) Setup

    private func setupElevenLabsCallbacks() {
        // Stream raw PCM to ElevenLabs (base64-encoded internally)
        // When backgrounded, buffer locally instead of streaming
        audioCaptureService.onRawPCMReady = { [weak self] pcmData in
            guard let self else { return }
            if self.backgroundManager.isInBackground {
                self.backgroundManager.bufferAudio(pcmData)
            } else {
                self.elevenLabsService.sendAudio(pcmData)
            }
            self.speakerIdService.processAudio(pcmData)
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

    // MARK: - Post-Recording Result

    private func applyPostRecordingResult(_ result: PostRecordingProcessor.ProcessedResult, to meeting: Meeting) {
        meeting.segments.removeAll()
        let existingNames = meeting.speakerNames
        let userIdx = meeting.userSpeakerIndex

        for seg in result.segments {
            let isUser = (seg.speaker == userIdx)
            let label: String? = isUser ? "You" : existingNames[seg.speaker]

            let segment = TranscriptSegment(
                text: seg.text,
                startTime: seg.startTime,
                endTime: seg.endTime,
                source: "microphone",
                speaker: seg.speaker,
                speakerLabel: label,
                isUserSpeaker: isUser
            )
            meeting.segments.append(segment)
        }
        meeting.rawTranscript = result.fullText
        committedText = result.fullText
    }

    // MARK: - Deepgram Setup

    private func setupDeepgramCallbacks() {
        // Stream raw PCM to Deepgram
        // When backgrounded, buffer locally instead of streaming
        audioCaptureService.onRawPCMReady = { [weak self] pcmData in
            guard let self else { return }
            if self.backgroundManager.isInBackground {
                self.backgroundManager.bufferAudio(pcmData)
            } else {
                self.deepgramService.sendAudio(pcmData)
            }
            self.speakerIdService.processAudio(pcmData)
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
                let isUser = (run.speaker == meeting.userSpeakerIndex)
                let label: String? = isUser ? "You" : meeting.speakerNames[run.speaker]
                let segment = TranscriptSegment(
                    text: runText,
                    startTime: startTime,
                    endTime: endTime,
                    source: "microphone",
                    speaker: run.speaker,
                    speakerLabel: label,
                    isUserSpeaker: isUser
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
