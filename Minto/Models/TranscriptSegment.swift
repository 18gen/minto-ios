import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var text: String
    var startTime: Double
    var endTime: Double
    var source: String?
    var speaker: Int?
    var speakerLabel: String?
    var isUserSpeaker: Bool?
    var meeting: Meeting?

    init(
        text: String,
        startTime: Double,
        endTime: Double,
        source: String = "system",
        speaker: Int? = nil,
        speakerLabel: String? = nil,
        isUserSpeaker: Bool = false
    ) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.source = source
        self.speaker = speaker
        self.speakerLabel = speakerLabel
        self.isUserSpeaker = isUserSpeaker
    }
}
