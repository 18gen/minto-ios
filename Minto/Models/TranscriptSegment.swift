import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var text: String
    var startTime: Double
    var endTime: Double
    var source: String? // "system" or "microphone" — optional for lightweight migration
    var speaker: Int? // speaker index from diarization (nil for legacy/undiarized)
    var meeting: Meeting?

    init(text: String, startTime: Double, endTime: Double, source: String = "system", speaker: Int? = nil) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.source = source
        self.speaker = speaker
    }
}
