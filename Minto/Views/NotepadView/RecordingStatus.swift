import SwiftUI

struct RecordingStatus: View {
    private let coordinator = iOSRecordingCoordinator.shared

    var body: some View {
        VStack(spacing: 6) {
            if let error = coordinator.recordingError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if coordinator.isProcessingBatch {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(coordinator.batchProcessingStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
