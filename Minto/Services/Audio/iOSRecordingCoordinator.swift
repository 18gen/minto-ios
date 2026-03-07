import Foundation
import SwiftData
import Observation
import AVFoundation

enum TranscriptionMode: String, CaseIterable {
    case cloud    // Deepgram Nova-3 (real-time, diarization)
    case onDevice // Whisper / Kotoba (offline, no diarization)
}

@Observable
@MainActor
final class iOSRecordingCoordinator {
    static let shared = iOSRecordingCoordinator()

    private let audioCaptureService = iOSAudioCaptureService()
    private let whisperService = WhisperService()
    private let deepgramService = DeepgramStreamingService()

    var isRecording = false
    var currentMeeting: Meeting?
    var recordingError: String?
    var transcriptionMode: TranscriptionMode = .cloud

    var currentPartial: String = ""
    var currentAudioLevel: Float = 0.0

    private var committedText: String = ""
    private var recordingStartDate: Date = .now
    private var levelPollTimer: Timer?

    private init() {}

    /// Resolves which transcription mode to use based on available keys.
    private func resolveTranscriptionMode() -> TranscriptionMode {
        // If user has set .cloud but no Deepgram key, fall back
        if transcriptionMode == .cloud && AppSettings.deepgramKey.isEmpty {
            return .onDevice
        }
        // If user has set .onDevice but no Whisper key, try cloud
        if transcriptionMode == .onDevice && AppSettings.whisperKey.isEmpty && !AppSettings.deepgramKey.isEmpty {
            return .cloud
        }
        return transcriptionMode
    }

    func startRecording(meeting: Meeting, modelContext: ModelContext) async {
        recordingError = nil
        currentMeeting = meeting
        meeting.status = "recording"
        committedText = meeting.rawTranscript
        currentPartial = ""
        recordingStartDate = .now

        let effectiveMode = resolveTranscriptionMode()

        // Validate we have at least one API key
        if effectiveMode == .onDevice && AppSettings.whisperKey.isEmpty {
            recordingError = "No API key configured. Add a Deepgram or OpenAI key."
            meeting.status = "idle"
            return
        }

        // Request mic permission
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { continuation in
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
        if effectiveMode == .cloud {
            setupDeepgramCallbacks()
        } else {
            setupWhisperCallbacks()
        }

        do {
            // Connect Deepgram WebSocket before starting audio capture
            if effectiveMode == .cloud {
                try deepgramService.connect()
            }

            try await audioCaptureService.startCapture()
            isRecording = true

            levelPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.currentAudioLevel = self.audioCaptureService.currentAudioLevel
                    if self.recordingError != nil && self.audioCaptureService.hasReceivedNonSilence {
                        self.recordingError = nil
                    }
                }
            }

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
            deepgramService.disconnect()
        }
    }

    func stopRecording() async {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
        currentAudioLevel = 0.0

        deepgramService.disconnect()
        audioCaptureService.onRawPCMReady = nil
        audioCaptureService.onAudioChunkReady = nil

        await audioCaptureService.stopCapture()

        currentPartial = ""
        isRecording = false
        currentMeeting?.status = "done"
        currentMeeting?.endDate = .now
        currentMeeting = nil
        committedText = ""
    }

    // MARK: - Deepgram (Cloud) Setup

    private func setupDeepgramCallbacks() {
        // Stream raw PCM to Deepgram
        audioCaptureService.onRawPCMReady = { [weak self] pcmData in
            self?.deepgramService.sendAudio(pcmData)
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
               lastSegment.source == "microphone" {
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

    nonisolated private static let whisperHallucinations: Set<String> = [
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
