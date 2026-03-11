import SwiftData
import SwiftUI

struct NotepadView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting

    @State private var currentPage: NotePage = .notes
    @FocusState private var notesFocused: Bool

    @State private var chatConversation: ChatConversation?
    @State private var chatInitialPrompt: String?
    @State private var chatInitialRecipeLabel: String?

    @State private var enhancer = NoteEnhancer()

    var body: some View {
        ZStack(alignment: .bottom) {
            NoteTranscriptPager(currentPage: $currentPage, meeting: meeting) {
                content
            }
            NotepadBottomBar(
                meeting: meeting,
                currentPage: $currentPage,
                isNotepadEditing: notesFocused,
                onDismissKeyboard: { notesFocused = false },
                onOpenChat: { text, recipeLabel in
                    openChat(prompt: text, recipeLabel: recipeLabel)
                }
            )
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .fullScreenCover(item: $chatConversation) { conv in
            ChatView(
                conversation: conv,
                initialPrompt: chatInitialPrompt,
                initialRecipeLabel: chatInitialRecipeLabel
            )
            .id(conv.persistentModelID)
        }
        .onAppear {
            if !meeting.augmentedNotes.isEmpty {
                enhancer.showingEnhanced = true
            }
        }
    }

    private func openChat(prompt: String, recipeLabel: String?) {
        Haptic.impact(.light)
        var context = ""
        if !meeting.userNotes.isEmpty {
            context += "ユーザーのメモ:\n\(meeting.userNotes)\n\n"
        }
        if !meeting.rawTranscript.isEmpty {
            context += "文字起こし:\n\(meeting.rawTranscript)"
        }

        let conv = ChatConversation(meetingsContext: context)
        modelContext.insert(conv)
        chatInitialPrompt = prompt
        chatInitialRecipeLabel = recipeLabel
        chatConversation = conv
    }
}

// MARK: - Subviews

private extension NotepadView {
    var content: some View {
        VStack(spacing: 5) {
            metadataRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if let error = enhancer.augmentError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }

            if enhancer.showingEnhanced && !meeting.augmentedNotes.isEmpty {
                ScrollView {
                    EnhancedNotesView(text: meeting.augmentedNotes)
                }
            } else {
                TextEditor(text: $meeting.userNotes)
                    .focused($notesFocused)
                    .font(.system(size: 17))
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
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

                NoteToggle(
                    showingEnhanced: $enhancer.showingEnhanced,
                    isLoading: enhancer.isAugmenting,
                    hasTranscript: !meeting.rawTranscript.isEmpty,
                    onTapEnhance: { enhancer.tapEnhance(meeting: meeting) },
                    onSelectTemplate: { enhancer.enhance(meeting: meeting, template: $0) }
                )
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

    var dateBadgeText: String {
        let cal = Calendar.current
        if cal.isDateInToday(meeting.startDate) { return "Today" }
        if cal.isDateInTomorrow(meeting.startDate) { return "Tomorrow" }
        return meeting.startDate.formatted(date: .abbreviated, time: .shortened)
    }
}
