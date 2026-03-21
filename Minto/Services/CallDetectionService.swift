import CallKit
import Observation
import UserNotifications

@Observable
final class CallDetectionService: NSObject, CXCallObserverDelegate, @unchecked Sendable {
    static let shared = CallDetectionService()

    private let callObserver = CXCallObserver()
    private(set) var isOnCall = false
    private var hasNotifiedForCurrentCall = false

    private override init() {
        super.init()
        callObserver.setDelegate(self, queue: .main)
        requestNotificationPermission()
    }

    // MARK: - CXCallObserverDelegate

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let connected = !call.hasEnded && call.hasConnected

        if connected && !isOnCall {
            isOnCall = true
            hasNotifiedForCurrentCall = false
            sendCallNotification()
        } else if call.hasEnded {
            // Only clear if no other active calls remain
            let hasOtherActive = callObserver.calls.contains { !$0.hasEnded }
            if !hasOtherActive {
                isOnCall = false
                hasNotifiedForCurrentCall = false
            }
        }
    }

    // MARK: - Active Call Check (on foreground)

    func checkForActiveCalls() {
        isOnCall = callObserver.calls.contains { !$0.hasEnded && $0.hasConnected }
    }

    // MARK: - Local Notification

    private func sendCallNotification() {
        guard !hasNotifiedForCurrentCall else { return }
        hasNotifiedForCurrentCall = true

        let content = UNMutableNotificationContent()
        content.title = L("call.notificationTitle")
        content.body = L("call.notificationBody")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "call-recording-prompt", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
