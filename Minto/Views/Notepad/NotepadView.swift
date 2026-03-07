import SwiftUI
import SwiftData

struct NotepadView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting

    @State private var showTranscriptPanel = false
    @State private var isAugmenting = false
    @State private var augmentError: String?

    private let claudeService = ClaudeService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            overlay
        }
        .background(AppTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }
}

// MARK: - Subviews
private extension NotepadView {
    var content: some View {
        VStack(spacing: 5) {
            metadataRow
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)

            TextEditor(text: $meeting.userNotes)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)

            if let augmentError {
                Text(augmentError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 100)
    }

    var metadataRow: some View {
        VStack(spacing: 10) {
            TextField("New Note", text: $meeting.title)
                .textFieldStyle(.plain)
                .font(.system(.title, design: .serif))
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Label(dateBadgeText, systemImage: "calendar")
                    .metadataButtonStyle()

                if let attendeesLabelText {
                    Label(attendeesLabelText, systemImage: "person.2")
                        .metadataButtonStyle()
                }

                Spacer()
            }
        }
    }

    var overlay: some View {
        NotepadBottomBar(meeting: meeting, showTranscriptPanel: $showTranscriptPanel)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { await augment() }
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .disabled(isGenerateDisabled || isAugmenting)
        }
    }
}

// MARK: - Computed helpers
private extension NotepadView {
    var shareText: String {
        var parts: [String] = []
        if !meeting.title.isEmpty { parts.append(meeting.title) }
        if !meeting.userNotes.isEmpty { parts.append(meeting.userNotes) }
        if !meeting.augmentedNotes.isEmpty { parts.append(meeting.augmentedNotes) }
        return parts.joined(separator: "\n\n")
    }

    var isGenerateDisabled: Bool {
        meeting.rawTranscript.isEmpty && meeting.userNotes.isEmpty
    }

    var dateBadgeText: String {
        let cal = Calendar.current
        if cal.isDateInToday(meeting.startDate) { return "Today" }
        if cal.isDateInTomorrow(meeting.startDate) { return "Tomorrow" }
        return meeting.startDate.formatted(date: .abbreviated, time: .shortened)
    }

    var event: CalendarEvent? {
        guard let id = meeting.calendarEventID else { return nil }
        return GoogleCalendarService.shared.upcomingEvents.first { $0.id == id }
    }

    var attendeesLabelText: String? {
        guard let attendees = event?.attendees, !attendees.isEmpty else { return nil }
        return attendees.count == 1 ? attendees[0] : "\(attendees.count) attendees"
    }
}

// MARK: - Actions
private extension NotepadView {
    func augment() async {
        isAugmenting = true
        augmentError = nil
        meeting.status = "augmenting"

        do {
            meeting.augmentedNotes = try await claudeService.augmentNotes(
                userNotes: meeting.userNotes,
                transcript: meeting.rawTranscript,
                toneMode: meeting.toneMode
            )
            meeting.status = "done"
        } catch {
            augmentError = error.localizedDescription
            meeting.status = meeting.rawTranscript.isEmpty ? "idle" : "done"
        }

        isAugmenting = false
    }
}
