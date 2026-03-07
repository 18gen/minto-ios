import Foundation
import SwiftData

@Model
final class Meeting {
    var title: String
    var startDate: Date
    var endDate: Date?

    var userNotes: String
    var rawTranscript: String
    var augmentedNotes: String

    var toneMode: String
    var status: String

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.meeting)
    var segments: [TranscriptSegment]

    init(
        title: String = "New Meeting",
        startDate: Date = .now,
        toneMode: String = "business"
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = nil
        self.userNotes = ""
        self.rawTranscript = ""
        self.augmentedNotes = ""
        self.toneMode = toneMode
        self.status = "idle"
        self.segments = []
    }
}
