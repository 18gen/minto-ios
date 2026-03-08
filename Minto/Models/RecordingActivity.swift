import ActivityKit
import Foundation

struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isPaused: Bool
    }

    var meetingTitle: String
}
