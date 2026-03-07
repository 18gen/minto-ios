import Foundation
import SwiftData
import Observation
import AVFoundation

@Observable
@MainActor
final class iOSRecordingCoordinator {
    static let shared = iOSRecordingCoordinator()

    private let audioCaptureService = iOSAudioCaptureService()
    private let whisperService = WhisperService()

    var isRecording = false
    var currentMeeting: Meeting?
    var recordingError: String?

    var currentPartial: String = ""
    var currentAudioLevel: Float = 0.0

    private var committedText: String = ""
    private var recordingStartDate: Date = .now
    private var levelPollTimer: Timer?

    private init() {}

    func startRecording(meeting: Meeting, modelContext: ModelContext) async {
        recordingError = nil
        currentMeeting = meeting
        meeting.status = "recording"
        committedText = ""
        currentPartial = ""
        recordingStartDate = .now

        let apiKey = AppSettings.whisperKey
        guard !apiKey.isEmpty else {
            recordingError = "OpenAI API key not configured. Add it in Settings."
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

        audioCaptureService.onAudioChunkReady = { [weak self] wavData in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.currentPartial = "..."
            }
            Task {
                await self.transcribeChunk(wavData)
            }
        }

        do {
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
        }
    }

    func stopRecording() async {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
        currentAudioLevel = 0.0

        await audioCaptureService.stopCapture()

        currentPartial = ""
        isRecording = false
        currentMeeting?.status = "done"
        currentMeeting?.endDate = .now
        currentMeeting = nil
        committedText = ""
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

                // All segments are microphone on iOS
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
