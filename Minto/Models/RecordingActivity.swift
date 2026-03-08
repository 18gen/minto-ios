import ActivityKit
import Foundation

struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var isPaused: Bool
    }

    var meetingTitle: String
}
