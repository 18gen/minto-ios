import SwiftData
import SwiftUI

struct TranscriptPanelView: View {
    @Bindable var meeting: Meeting
    var isInline: Bool = false
    private let coordinator = iOSRecordingCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    @State private var editingSpeaker: Int?
    @State private var editingSpeakerName: String = ""

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
        .renameAlert(editingSpeaker: $editingSpeaker, editingSpeakerName: $editingSpeakerName, meeting: meeting)
    }

    // MARK: - Sheet mode

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
            .renameAlert(editingSpeaker: $editingSpeaker, editingSpeakerName: $editingSpeakerName, meeting: meeting)
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
                                isUserSpeaker: segment.isUserSpeaker == true,
                                speakerColor: colorForSegment(segment)
                            )
                            .id(segment.id)
                        }

                        if !coordinator.currentPartial.isEmpty {
                            TranscriptBubble(
                                text: coordinator.currentPartial,
                                isPartial: true,
                                isUserSpeaker: false,
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
        let isUser = segment.isUserSpeaker == true
        let name = displayName(for: segment)
        let color = colorForSegment(segment)

        HStack(spacing: 6) {
            Text(formatTime(segment.startTime))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if segment.speaker != nil {
                // Avatar circle
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(color))

                Text(name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(color)
            }

            Spacer()
        }
        .padding(.top, index == 0 ? 8 : 4)
        .contentShape(Rectangle())
        .contextMenu {
            if let speaker = segment.speaker {
                Button {
                    editingSpeakerName = meeting.speakerNames[speaker] ?? ""
                    editingSpeaker = speaker
                } label: {
                    Label("Rename Speaker", systemImage: "pencil")
                }

                if !isUser {
                    Button {
                        meeting.markSpeakerAsUser(speaker)
                        Haptic.notification(.success)
                    } label: {
                        Label("Mark as Me", systemImage: "person.crop.circle.badge.checkmark")
                    }
                } else {
                    Button(role: .destructive) {
                        meeting.userSpeakerIndex = nil
                        for seg in meeting.segments where seg.speaker == speaker {
                            seg.isUserSpeaker = false
                            if seg.speakerLabel == "You" { seg.speakerLabel = nil }
                        }
                        Haptic.notification(.success)
                    } label: {
                        Label("Unmark as Me", systemImage: "person.crop.circle.badge.minus")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func shouldShowHeader(at index: Int, in segments: [TranscriptSegment]) -> Bool {
        if index == 0 { return true }
        let prev = segments[index - 1]
        let curr = segments[index]
        return prev.speaker != curr.speaker || prev.source != curr.source
    }

    private func displayName(for segment: TranscriptSegment) -> String {
        if let label = segment.speakerLabel, !label.isEmpty { return label }
        if let speaker = segment.speaker, let name = meeting.speakerNames[speaker], !name.isEmpty {
            return name
        }
        if let speaker = segment.speaker { return "Speaker \(speaker + 1)" }
        return "Unknown"
    }

    private func colorForSegment(_ segment: TranscriptSegment) -> Color {
        if segment.isUserSpeaker == true { return AppTheme.userSpeakerColor }
        guard let speaker = segment.speaker else { return AppTheme.accent }
        return AppTheme.speakerColors[speaker % AppTheme.speakerColors.count]
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Rename Alert Modifier

private struct RenameAlertModifier: ViewModifier {
    @Binding var editingSpeaker: Int?
    @Binding var editingSpeakerName: String
    let meeting: Meeting

    func body(content: Content) -> some View {
        content.alert("Rename Speaker", isPresented: .init(
            get: { editingSpeaker != nil },
            set: { if !$0 { editingSpeaker = nil } }
        )) {
            TextField("Name", text: $editingSpeakerName)
            Button("OK") {
                if let speaker = editingSpeaker {
                    meeting.renameSpeaker(speaker, to: editingSpeakerName)
                }
                editingSpeaker = nil
            }
            Button("Cancel", role: .cancel) { editingSpeaker = nil }
        } message: {
            Text("Enter a name for this speaker")
        }
    }
}

private extension View {
    func renameAlert(editingSpeaker: Binding<Int?>, editingSpeakerName: Binding<String>, meeting: Meeting) -> some View {
        modifier(RenameAlertModifier(editingSpeaker: editingSpeaker, editingSpeakerName: editingSpeakerName, meeting: meeting))
    }
}

// MARK: - Transcript Bubble

private struct TranscriptBubble: View {
    let text: String
    let isPartial: Bool
    var isUserSpeaker: Bool = false
    var speakerColor: Color?

    private var alignRight: Bool { isUserSpeaker }

    private var bubbleColor: Color {
        if isPartial { return Color.secondary.opacity(0.06) }
        if isUserSpeaker { return AppTheme.userSpeakerColor.opacity(0.12) }
        if let speakerColor { return speakerColor.opacity(0.10) }
        return AppTheme.accent.opacity(0.10)
    }

    private var leadingAccent: Color? {
        if isPartial || isUserSpeaker { return nil }
        return speakerColor
    }

    var body: some View {
        HStack {
            if alignRight { Spacer(minLength: 40) }
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
            if !alignRight { Spacer(minLength: 40) }
        }
    }
}
