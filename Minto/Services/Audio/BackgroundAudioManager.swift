import Foundation
import UIKit

/// Manages audio buffering and background task lifecycle when the app is backgrounded
/// during an active recording session.
/// Thread-safe via NSLock — accessed from both main thread and audio callbacks.
final class BackgroundAudioManager: @unchecked Sendable {
    private let lock = NSLock()
    private var _isInBackground = false
    private var _buffer: [Data] = []
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    var isInBackground: Bool {
        lock.withLock { _isInBackground }
    }

    /// Buffer audio data while in background instead of streaming.
    func bufferAudio(_ data: Data) {
        lock.withLock { _buffer.append(data) }
    }

    /// Called when the app enters the background.
    @MainActor
    func enterBackground(disconnectStreams: () -> Void) {
        lock.withLock { _isInBackground = true }
        disconnectStreams()

        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor [weak self] in
                self?.endBackgroundTask()
            }
        }
    }

    /// Called when the app returns to foreground. Returns any buffered audio.
    @MainActor
    func enterForeground() -> [Data] {
        endBackgroundTask()
        return lock.withLock {
            let buf = _buffer
            _buffer = []
            _isInBackground = false
            return buf
        }
    }

    /// Reset all state (call on recording stop).
    @MainActor
    func reset() {
        lock.withLock {
            _isInBackground = false
            _buffer = []
        }
        endBackgroundTask()
    }

    @MainActor
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}
