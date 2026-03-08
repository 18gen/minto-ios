import ActivityKit
import SwiftUI
import WidgetKit

private let mintColor = Color(red: 0.243, green: 0.706, blue: 0.537) // #3EB489

struct MintoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(context.state.isPaused ? .orange : mintColor)
                            .frame(width: 7, height: 7)
                        Text(context.state.isPaused ? "Paused" : "REC")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(context.state.isPaused ? .orange : mintColor)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(startDate: context.state.startDate)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.meetingTitle)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                        Text("Minto")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(mintColor.opacity(0.7))
                    .padding(.top, 2)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(context.state.isPaused ? .orange : mintColor)
                        .frame(width: 6, height: 6)
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundStyle(mintColor)
                }
            } compactTrailing: {
                timerText(startDate: context.state.startDate)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundStyle(mintColor)
            }
        }
    }

    // MARK: - Lock Screen

    private func lockScreenView(context: ActivityViewContext<RecordingAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: icon + title
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 13))
                    .foregroundStyle(mintColor)

                Text(context.attributes.meetingTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Spacer()
            }

            // Center: large timer
            timerText(startDate: context.state.startDate)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            // Mint divider
            RoundedRectangle(cornerRadius: 1)
                .fill(mintColor.opacity(0.35))
                .frame(height: 2)

            // Bottom row: status + branding
            HStack(spacing: 6) {
                Circle()
                    .fill(context.state.isPaused ? .orange : mintColor)
                    .frame(width: 6, height: 6)

                Text(context.state.isPaused ? "Paused" : "Recording")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Text("Minto")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(mintColor.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .activityBackgroundTint(.black.opacity(0.85))
    }

    // MARK: - Helpers

    private func timerText(startDate: Date) -> Text {
        Text(timerInterval: startDate...startDate.addingTimeInterval(36000), countsDown: false)
    }
}
