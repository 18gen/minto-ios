import SwiftData
import SwiftUI

struct TranscriptContent: View {
    @Bindable var meeting: Meeting
    private let coordinator = iOSRecordingCoordinator.shared

    @State private var editingSpeaker: Int?
    @State private var editingSpeakerName: String = ""

    var body: some View {
        transcriptScrollView
            .renameAlert(editingSpeaker: $editingSpeaker, editingSpeakerName: $editingSpeakerName, meeting: meeting)
    }

    // MARK: - Scroll Content

    private var transcriptScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    Text(L("transcript.consentNotice"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)

                    if meeting.segments.isEmpty && meeting.rawTranscript.isEmpty && coordinator.currentPartial.isEmpty {
                        Text(L("empty.transcriptWillAppear"))
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
            Text(TimeFormatting.mmss(segment.startTime))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if segment.speaker != nil {
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
                    Label(L("button.renameSpeaker"), systemImage: "pencil")
                }

                if !isUser {
                    Button {
                        meeting.markSpeakerAsUser(speaker)
                        Haptic.notification(.success)
                    } label: {
                        Label(L("button.markAsMe"), systemImage: "person.crop.circle.badge.checkmark")
                    }
                } else {
                    Button(role: .destructive) {
                        meeting.userSpeakerIndex = nil
                        for seg in meeting.segments where seg.speaker == speaker {
                            seg.speakerLabel = nil
                            seg.isUserSpeaker = false
                        }
                        Haptic.notification(.success)
                    } label: {
                        Label(L("button.unmarkAsMe"), systemImage: "person.crop.circle.badge.minus")
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
        if segment.isUserSpeaker == true { return L("speaker.you") }
        if let label = segment.speakerLabel, !label.isEmpty { return label }
        if let speaker = segment.speaker, let name = meeting.speakerNames[speaker], !name.isEmpty {
            return name
        }
        if let speaker = segment.speaker { return L("speaker.numbered", speaker + 1) }
        return L("speaker.unknown")
    }

    private func colorForSegment(_ segment: TranscriptSegment) -> Color {
        if segment.isUserSpeaker == true { return AppTheme.userSpeakerColor }
        guard let speaker = segment.speaker else { return AppTheme.accent }
        return AppTheme.speakerColors[speaker % AppTheme.speakerColors.count]
    }
}

// MARK: - Rename Alert Modifier

private struct RenameAlertModifier: ViewModifier {
    @Binding var editingSpeaker: Int?
    @Binding var editingSpeakerName: String
    let meeting: Meeting

    func body(content: Content) -> some View {
        content.alert(L("alert.renameTitle"), isPresented: .init(
            get: { editingSpeaker != nil },
            set: { if !$0 { editingSpeaker = nil } }
        )) {
            TextField(L("placeholder.name"), text: $editingSpeakerName)
            Button(L("button.ok")) {
                if let speaker = editingSpeaker {
                    meeting.renameSpeaker(speaker, to: editingSpeakerName)
                }
                editingSpeaker = nil
            }
            Button(L("button.cancel"), role: .cancel) { editingSpeaker = nil }
        } message: {
            Text(L("transcript.enterName"))
        }
    }
}

extension View {
    func renameAlert(editingSpeaker: Binding<Int?>, editingSpeakerName: Binding<String>, meeting: Meeting) -> some View {
        modifier(RenameAlertModifier(editingSpeaker: editingSpeaker, editingSpeakerName: editingSpeakerName, meeting: meeting))
    }
}
