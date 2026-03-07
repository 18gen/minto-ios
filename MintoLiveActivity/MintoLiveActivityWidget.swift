import ActivityKit
import WidgetKit
import SwiftUI

struct MintoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            // Lock Screen / StandBy banner
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.meetingTitle)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        if context.state.isPaused {
                            Label("Paused", systemImage: "pause.fill")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Label("Recording", systemImage: "circle.fill")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "record.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(context.state.isPaused ? .orange : .red)
            } compactTrailing: {
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            } minimal: {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Lock Screen

    private func lockScreenView(context: ActivityViewContext<RecordingAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.isPaused ? "pause.circle.fill" : "record.circle")
                .font(.system(size: 24))
                .foregroundStyle(context.state.isPaused ? .orange : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.meetingTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(context.state.isPaused ? "Paused" : "Recording")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatTime(context.state.elapsedSeconds))
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.7))
    }

    // MARK: - Helpers

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
