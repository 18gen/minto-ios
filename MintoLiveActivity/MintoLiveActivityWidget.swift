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
                    timerText(state: context.state)
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
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
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
                timerText(state: context.state)
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
        HStack(spacing: 14) {
            // App logo from asset catalog
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Title + timer
            VStack(alignment: .leading) {
                Text(context.attributes.meetingTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                timerText(state: context.state)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            // Recording indicator
            Circle()
                .fill(context.state.isPaused ? .orange : mintColor)
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .activityBackgroundTint(.clear)
    }

    // MARK: - Helpers

    private func timerText(state: RecordingAttributes.ContentState) -> Text {
        if state.isPaused {
            // Show frozen static time when paused
            let m = state.accumulatedSeconds / 60
            let s = state.accumulatedSeconds % 60
            return Text(String(format: "%02d:%02d", m, s))
        } else {
            // Live system timer from synthetic start date
            return Text(timerInterval: state.startDate...state.startDate.addingTimeInterval(36000), countsDown: false)
        }
    }
}
