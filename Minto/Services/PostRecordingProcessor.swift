import Foundation

/// Handles post-recording batch transcription (diarization) and LLM transcript correction.
/// Extracted from iOSRecordingCoordinator to keep it focused on recording lifecycle.
@MainActor
final class PostRecordingProcessor {
    private let batchService = ElevenLabsBatchService()

    var isProcessing = false
    var statusMessage = ""

    struct ProcessedResult {
        let fullText: String
        let segments: [SegmentData]
    }

    struct SegmentData {
        let text: String
        let startTime: Double
        let endTime: Double
        let speaker: Int
    }

    /// Run batch diarization + LLM correction on a saved audio file.
    func process(meeting: Meeting, audioURL: URL) async -> ProcessedResult? {
        isProcessing = true
        defer {
            isProcessing = false
            statusMessage = ""
            try? FileManager.default.removeItem(at: audioURL)
        }

        // Step 1: Batch transcription with speaker diarization
        statusMessage = "Analyzing speakers..."
        var fullText = meeting.rawTranscript
        var segments: [SegmentData] = []

        do {
            let result = try await batchService.transcribe(audioFileURL: audioURL)
            fullText = result.text
            segments = result.utterances.map { utterance in
                SegmentData(
                    text: utterance.text,
                    startTime: utterance.start,
                    endTime: utterance.end,
                    speaker: Self.parseSpeakerIndex(utterance.speakerId)
                )
            }
        } catch {
            print("Batch transcription failed: \(error.localizedDescription)")
            return nil
        }

        // Step 2: LLM transcript correction (via proxy — always available)
        statusMessage = "Polishing transcript..."
        do {
            fullText = try await ClaudeService.shared.correctTranscript(
                rawTranscript: fullText
            )
        } catch {
            print("LLM correction failed: \(error.localizedDescription)")
        }

        return ProcessedResult(fullText: fullText, segments: segments)
    }

    /// Parse "speaker_0" → 0, "speaker_1" → 1, etc.
    private static func parseSpeakerIndex(_ speakerId: String) -> Int {
        if let lastComponent = speakerId.split(separator: "_").last,
           let index = Int(lastComponent)
        {
            return index
        }
        return 0
    }
}
