import ActivityKit
import Foundation

struct RecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var isPaused: Bool
        var accumulatedSeconds: Int
    }

    var meetingTitle: String
}
