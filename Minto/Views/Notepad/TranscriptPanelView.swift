import SwiftUI
import SwiftData

struct TranscriptPanelView: View {
    @Bindable var meeting: Meeting
    var isInline: Bool = false
    @State private var coordinator = iOSRecordingCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    /// User-assigned speaker names, keyed by speaker index.
    @State private var speakerNames: [Int: String] = [:]
    @State private var editingSpeaker: Int?

    // Speaker colors for diarization
    private static let speakerColors: [Color] = [
        AppTheme.accent,
        Color(red: 0.65, green: 0.45, blue: 0.70), // purple
        Color(red: 0.45, green: 0.65, blue: 0.50), // green
        Color(red: 0.70, green: 0.55, blue: 0.40), // orange
    ]

    var body: some View {
        if isInline {
            inlineBody
        } else {
            sheetBody
        }
    }

    // MARK: - Inline mode (embedded in pager)

    private var inlineBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                Button {
                    UIPasteboard.general.string = meeting.rawTranscript
                    Haptic.notification(.success)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            transcriptScrollView
        }
        .alert("Rename Speaker", isPresented: .init(
            get: { editingSpeaker != nil },
            set: { if !$0 { editingSpeaker = nil } }
        )) {
            if let speaker = editingSpeaker {
                TextField("Name", text: .init(
                    get: { speakerNames[speaker] ?? "" },
                    set: { speakerNames[speaker] = $0 }
                ))
                Button("OK") { editingSpeaker = nil }
                Button("Cancel", role: .cancel) { editingSpeaker = nil }
            }
        } message: {
            Text("Enter a name for this speaker")
        }
    }

    // MARK: - Sheet mode (existing behavior)

    private var sheetBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcriptScrollView
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        UIPasteboard.general.string = meeting.rawTranscript
                        Haptic.notification(.success)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Speaker", isPresented: .init(
                get: { editingSpeaker != nil },
                set: { if !$0 { editingSpeaker = nil } }
            )) {
                if let speaker = editingSpeaker {
                    TextField("Name", text: .init(
                        get: { speakerNames[speaker] ?? "" },
                        set: { speakerNames[speaker] = $0 }
                    ))
                    Button("OK") { editingSpeaker = nil }
                    Button("Cancel", role: .cancel) { editingSpeaker = nil }
                }
            } message: {
                Text("Enter a name for this speaker")
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Shared scroll content

    private var transcriptScrollView: some View {
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
                            let showHeader = shouldShowHeader(at: index, in: sortedSegments)

                            if showHeader {
                                speakerHeader(segment: segment, index: index)
                            }

                            TranscriptBubble(
                                text: segment.text,
                                isPartial: false,
                                source: segment.source ?? "system",
                                speaker: segment.speaker,
                                speakerColor: colorForSpeaker(segment.speaker)
                            )
                            .id(segment.id)
                        }

                        if !coordinator.currentPartial.isEmpty {
                            TranscriptBubble(
                                text: coordinator.currentPartial,
                                isPartial: true,
                                source: "microphone",
                                speaker: nil,
                                speakerColor: nil
                            )
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

    // MARK: - Speaker Header

    @ViewBuilder
    private func speakerHeader(segment: TranscriptSegment, index: Int) -> some View {
        HStack(spacing: 6) {
            Text(formatTime(segment.startTime))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let speaker = segment.speaker {
                Button {
                    editingSpeaker = speaker
                } label: {
                    Text(displayName(for: speaker))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(colorForSpeaker(speaker) ?? AppTheme.accent)
                }
            }

            Spacer()
        }
        .padding(.top, index == 0 ? 8 : 4)
    }

    // MARK: - Helpers

    private func shouldShowHeader(at index: Int, in segments: [TranscriptSegment]) -> Bool {
        if index == 0 { return true }
        let prev = segments[index - 1]
        let curr = segments[index]
        // Show header on speaker change or source change
        return prev.speaker != curr.speaker || prev.source != curr.source
    }

    private func displayName(for speaker: Int) -> String {
        if let name = speakerNames[speaker], !name.isEmpty {
            return name
        }
        return "Speaker \(speaker + 1)"
    }

    private func colorForSpeaker(_ speaker: Int?) -> Color? {
        guard let speaker else { return nil }
        return Self.speakerColors[speaker % Self.speakerColors.count]
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
    var speaker: Int?
    var speakerColor: Color?

    private var isSystem: Bool { source == "system" }

    private var bubbleColor: Color {
        if isPartial { return Color.secondary.opacity(0.06) }
        if let speakerColor {
            return speakerColor.opacity(0.10)
        }
        return AppTheme.accent.opacity(0.10)
    }

    private var leadingAccent: Color? {
        if isPartial || isSystem { return nil }
        return speakerColor
    }

    var body: some View {
        HStack {
            if !isSystem {
                Spacer(minLength: 40)
            }
            HStack(spacing: 0) {
                if let accent = leadingAccent {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accent)
                        .frame(width: 3)
                        .padding(.vertical, 4)
                }
                Text(text)
                    .font(.callout)
                    .foregroundStyle(isPartial ? .secondary : .primary)
                    .italic(isPartial)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if isSystem {
                Spacer(minLength: 40)
            }
        }
    }
}
