import SwiftUI

struct RecordingCapsule: View {
    @Bindable var meeting: Meeting

    private let coordinator = iOSRecordingCoordinator.shared

    var body: some View {
        CapsuleButton(
            icon: coordinator.isRecording ? "pause.fill" : "play.fill",
            style: coordinator.isRecording ? .cream : .darkOutline,
            size: .compact,
            isLoading: coordinator.isProcessingBatch
        ) {
            Task {
                if coordinator.isRecording {
                    await coordinator.stopRecording()
                } else {
                    await coordinator.startRecording(meeting: meeting)
                }
            }
        }
        .disabled(coordinator.isProcessingBatch)
    }
}
