import SwiftData
import SwiftUI

private struct SettingsRoute: Hashable {}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.startDate, order: .reverse) private var meetings: [Meeting]
    @State private var navigationPath = NavigationPath()
    @State private var vm = HomeViewModel()
    @FocusState private var askFocused: Bool

    @State private var showNewNoteSheet = false
    @State private var sheetMeeting: Meeting?
    @State private var chatPresentation: ChatPresentation?
    @State private var showChatDrawer = false
    @State private var isChatSearchExpanded = false

    var body: some View {
        DrawerContainer(isOpen: $showChatDrawer, isExpanded: $isChatSearchExpanded) {
            ChatDrawerView(
                currentConversation: nil,
                onSelect: { conv in
                    showChatDrawer = false
                    chatPresentation = ChatPresentation(
                        conversation: conv,
                        initialPrompt: nil,
                        initialRecipeLabel: nil,
                        initialRecipeTint: nil
                    )
                },
                onNewChat: {
                    showChatDrawer = false
                    let context = HomeViewModel.recentContext(from: meetings)
                    let conv = ChatConversation(meetingsContext: context)
                    modelContext.insert(conv)
                    chatPresentation = ChatPresentation(
                        conversation: conv,
                        initialPrompt: nil,
                        initialRecipeLabel: nil,
                        initialRecipeTint: nil
                    )
                },
                isSearchExpanded: $isChatSearchExpanded
            )
        } content: {
            NavigationStack(path: $navigationPath) {
                ZStack(alignment: .bottom) {
                    List {
                        HistorySection(meetings: meetings, onSelect: { meeting in
                            guard navigationPath.isEmpty else { return }
                            navigationPath.append(meeting)
                        }, onDelete: { meeting in
                            modelContext.delete(meeting)
                            try? modelContext.save()
                        })
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 12)
                    .contentMargins(.bottom, 120)
                    .onTapGesture { askFocused = false }

                    FloatingBar(
                        prompts: Prompt.home,
                        askText: $vm.askText,
                        isAsking: $vm.isAsking,
                        askFocus: $askFocused,
                        onSend: { navigateToChat(prompt: vm.askText) },
                        onPromptSelect: { navigateToChat(prompt: $0.prompt, recipeLabel: $0.label, recipeTint: $0.tint) }
                    ) {
                        Button { createQuickNote() } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(AppTheme.accent))
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.surfaceStroke, lineWidth: 1)
                                        .blendMode(.overlay)
                                )
                        }
                    }
                }
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle("Minto")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Haptic.impact(.light)
                            showChatDrawer = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            navigationPath.append(SettingsRoute())
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .navigationDestination(for: SettingsRoute.self) { _ in
                    SettingsView()
                }
                .navigationDestination(for: Meeting.self) { meeting in
                    NotepadView(meeting: meeting)
                }
                .task { await vm.onAppear() }
                .sheet(isPresented: $showNewNoteSheet, onDismiss: handleSheetDismiss) {
                    if let meeting = sheetMeeting {
                        NewNoteSheet(meeting: meeting)
                    }
                }
            }
        }
        .onChange(of: showChatDrawer) {
            if !showChatDrawer {
                isChatSearchExpanded = false
            }
        }
        .fullScreenCover(item: $chatPresentation) { presentation in
            ChatView(
                conversation: presentation.conversation,
                initialPrompt: presentation.initialPrompt,
                initialRecipeLabel: presentation.initialRecipeLabel,
                initialRecipeTint: presentation.initialRecipeTint
            )
        }
    }

    private func createQuickNote() {
        Haptic.impact(.light)
        let meeting = Meeting(title: "")
        modelContext.insert(meeting)
        try? modelContext.save()
        sheetMeeting = meeting
        showNewNoteSheet = true
    }

    private func navigateToChat(prompt: String, recipeLabel: String? = nil, recipeTint: AppTheme.PromptTint? = nil) {
        Haptic.impact(.light)
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let context = HomeViewModel.recentContext(from: meetings)
        vm.askText = ""
        askFocused = false

        let conv = ChatConversation(meetingsContext: context)
        modelContext.insert(conv)
        chatPresentation = ChatPresentation(
            conversation: conv,
            initialPrompt: text,
            initialRecipeLabel: recipeLabel,
            initialRecipeTint: recipeTint
        )
    }

    private func handleSheetDismiss() {
        guard let meeting = sheetMeeting else { return }

        let coordinator = iOSRecordingCoordinator.shared
        if coordinator.isRecording {
            Task { await coordinator.stopRecording() }
        }

        let titleEmpty = meeting.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if titleEmpty, meeting.userNotes.isEmpty, meeting.rawTranscript.isEmpty {
            modelContext.delete(meeting)
            try? modelContext.save()
        }

        sheetMeeting = nil
    }
}

