import ActivityKit
import Foundation

@MainActor
final class RecordingActivityManager {
    static let shared = RecordingActivityManager()
    private var currentActivity: Activity<RecordingAttributes>?

    private init() {}

    func startActivity(title: String, startDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RecordingAttributes(meetingTitle: title.isEmpty ? "Recording" : title)
        let state = RecordingAttributes.ContentState(startDate: startDate, isPaused: false)
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("Live Activity start failed: \(error)")
        }
    }

    func updateActivity(isPaused: Bool, startDate: Date) {
        guard let activity = currentActivity else { return }

        let state = RecordingAttributes.ContentState(
            startDate: startDate,
            isPaused: isPaused
        )
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    func endActivity() {
        guard let activity = currentActivity else { return }

        let finalState = RecordingAttributes.ContentState(
            startDate: .now,
            isPaused: false
        )
        let content = ActivityContent(state: finalState, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
