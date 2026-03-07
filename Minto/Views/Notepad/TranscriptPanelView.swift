import SwiftUI
import SwiftData

struct TranscriptPanelView: View {
    @Bindable var meeting: Meeting
    @State private var coordinator = iOSRecordingCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Transcript content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            Text("Always get consent when transcribing others.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 16)

                            if meeting.segments.isEmpty && meeting.rawTranscript.isEmpty && coordinator.currentPartial.isEmpty {
                                Text("Transcript will appear here during recording...")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 30)
                            } else if !meeting.segments.isEmpty {
                                let sortedSegments = meeting.segments.sorted { $0.startTime < $1.startTime }

                                ForEach(Array(sortedSegments.enumerated()), id: \.element.id) { index, segment in
                                    let isFirstOrSourceChanged = index == 0 ||
                                        sortedSegments[index - 1].source != segment.source

                                    if isFirstOrSourceChanged {
                                        Text(formatTime(segment.startTime))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .padding(.top, index == 0 ? 8 : 4)
                                    }

                                    TranscriptBubble(text: segment.text, isPartial: false, source: segment.source ?? "system")
                                        .id(segment.id)
                                }

                                if !coordinator.currentPartial.isEmpty {
                                    TranscriptBubble(text: coordinator.currentPartial, isPartial: true, source: "microphone")
                                        .id("partial")
                                }
                            } else if !meeting.rawTranscript.isEmpty || !coordinator.currentPartial.isEmpty {
                                Text(meeting.rawTranscript)
                                    .font(.callout)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .onChange(of: meeting.segments.count) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: coordinator.currentPartial) {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        UIPasteboard.general.string = meeting.rawTranscript
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

private struct TranscriptBubble: View {
    let text: String
    let isPartial: Bool
    var source: String = "system"

    private var isSystem: Bool { source == "system" }

    private var bubbleColor: Color {
        if isPartial { return Color.secondary.opacity(0.06) }
        return AppTheme.accent.opacity(0.10)
    }

    var body: some View {
        HStack {
            if !isSystem {
                Spacer(minLength: 40)
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(isPartial ? .secondary : .primary)
                .italic(isPartial)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if isSystem {
                Spacer(minLength: 40)
            }
        }
    }
}
