import SwiftData
import SwiftUI

struct NotepadView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting

    @State private var currentPage: NotePage = .notes
    @FocusState private var askFocused: Bool
    @State private var askText = ""
    @State private var isAsking = false

    @State private var chatPresentation: ChatPresentation?

    @State private var enhancer = NoteEnhancer()
    @State private var blockEditorVM: BlockEditorViewModel?
    @State private var augmentedEditorVM: BlockEditorViewModel?

    private var activeEditorVM: BlockEditorViewModel? {
        enhancer.showingEnhanced ? augmentedEditorVM : blockEditorVM
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NoteTranscriptPager(currentPage: $currentPage, meeting: meeting, onClearFocus: {
                askFocused = false
                activeEditorVM?.clearFocus()
            }) {
                content
            }
            NotepadBottomBar(
                meeting: meeting,
                currentPage: $currentPage,
                activeBlockEditorVM: activeEditorVM,
                askText: $askText,
                isAsking: $isAsking,
                askFocus: $askFocused,
                onDismissKeyboard: {
                    askFocused = false
                    activeEditorVM?.clearFocus()
                },
                onOpenChat: { text, recipeLabel, recipeTint in
                    openChat(prompt: text, recipeLabel: recipeLabel, recipeTint: recipeTint)
                }
            )
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onChange(of: askFocused) { _, focused in
            if focused {
                activeEditorVM?.clearFocus(resign: false)
            }
        }
        .onChange(of: activeEditorVM?.focusedBlockID) { _, newID in
            if newID != nil {
                askFocused = false
            }
        }
        .onChange(of: enhancer.showingEnhanced) { oldVal, newVal in
            // Clear focus on the outgoing editor when toggling
            if oldVal != newVal {
                if oldVal {
                    augmentedEditorVM?.clearFocus()
                } else {
                    blockEditorVM?.clearFocus()
                }
            }
            // Lazily create augmented editor VM
            if newVal, augmentedEditorVM == nil {
                augmentedEditorVM = BlockEditorViewModel(meeting: meeting, mode: .augmentedNotes)
            }
        }
        .onChange(of: enhancer.enhancementVersion) { _, _ in
            // Recreate augmented editor VM with fresh parsed blocks
            augmentedEditorVM = BlockEditorViewModel(meeting: meeting, mode: .augmentedNotes)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .fullScreenCover(item: $chatPresentation) { presentation in
            ChatView(
                conversation: presentation.conversation,
                initialPrompt: presentation.initialPrompt,
                initialRecipeLabel: presentation.initialRecipeLabel,
                initialRecipeTint: presentation.initialRecipeTint
            )
        }
        .onAppear {
            if !meeting.augmentedNotes.isEmpty {
                enhancer.showingEnhanced = true
            }
            if blockEditorVM == nil {
                blockEditorVM = BlockEditorViewModel(meeting: meeting, mode: .userNotes)
            }
            if enhancer.showingEnhanced, augmentedEditorVM == nil {
                augmentedEditorVM = BlockEditorViewModel(meeting: meeting, mode: .augmentedNotes)
            }
        }
    }

    private func openChat(prompt: String, recipeLabel: String?, recipeTint: Tint? = nil) {
        Haptic.impact(.light)
        var context = ""
        if !meeting.userNotes.isEmpty {
            context += "\(L("context.userNotes"))\n\(meeting.userNotes)\n\n"
        }
        if !meeting.rawTranscript.isEmpty {
            context += "\(L("context.transcript"))\n\(meeting.rawTranscript)"
        }

        chatPresentation = ChatFactory.makePresentation(
            in: modelContext,
            meetingsContext: context,
            prompt: prompt,
            recipeLabel: recipeLabel,
            recipeTint: recipeTint
        )
    }
}

// MARK: - Subviews

private extension NotepadView {
    var content: some View {
        GeometryReader { _ in
            ScrollView {
                VStack(spacing: 5) {
                    VStack(spacing: 10) {
                        NoteHeaderView(meeting: meeting, enhancer: enhancer)

                        HStack(spacing: 4) {
                            Label(dateBadgeText, systemImage: "calendar")
                                .metadataButtonStyle()
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if enhancer.showingEnhanced, let vm = augmentedEditorVM {
                        BlockEditorView(viewModel: vm)
                    } else if let vm = blockEditorVM {
                        BlockEditorView(viewModel: vm)
                    }
                }
                .padding(.bottom, 54)
            }
            .scrollDismissesKeyboard(.never)
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
        if cal.isDateInToday(meeting.startDate) { return L("label.today") }
        if cal.isDateInTomorrow(meeting.startDate) { return L("label.tomorrow") }
        return meeting.startDate.formatted(date: .abbreviated, time: .shortened)
    }
}
