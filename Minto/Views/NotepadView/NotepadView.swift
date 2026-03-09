import SwiftData
import SwiftUI

struct NotepadView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting

    @State private var currentPage: NotePage = .notes
    @State private var isAugmenting = false
    @State private var augmentError: String?

    private let claudeService = ClaudeService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            NoteTranscriptPager(currentPage: $currentPage, meeting: meeting) {
                content
            }
            NotepadBottomBar(meeting: meeting, currentPage: $currentPage)
        }
        .background(AppTheme.background.ignoresSafeArea())
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
                .font(.system(size: 17))
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
        .padding(.bottom, 54)
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

                Spacer()
            }
        }
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
            }
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
