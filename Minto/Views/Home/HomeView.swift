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
    @State private var showChat = false
    @State private var chatConversation: ChatConversation?
    @State private var chatInitialPrompt: String?
    @State private var showChatDrawer = false

    var body: some View {
        DrawerContainer(isOpen: $showChatDrawer) {
            ChatDrawerView(
                currentConversation: nil,
                onSelect: { conv in
                    showChatDrawer = false
                    chatConversation = conv
                    chatInitialPrompt = nil
                    // Delay presentation so drawer spring animation doesn't
                    // interfere with fullScreenCover transition.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showChat = true
                    }
                },
                onNewChat: {
                    showChatDrawer = false
                    let context = HomeViewModel.recentContext(from: meetings)
                    let conv = ChatConversation(meetingsContext: context)
                    modelContext.insert(conv)
                    chatConversation = conv
                    chatInitialPrompt = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showChat = true
                    }
                }
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

                    floatingBar
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
                .fullScreenCover(isPresented: $showChat) {
                    if let conv = chatConversation {
                        ChatView(
                            conversation: conv,
                            initialPrompt: chatInitialPrompt
                        )
                    }
                }
            }
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

    private func navigateToChat(prompt: String) {
        Haptic.impact(.light)
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let context = HomeViewModel.recentContext(from: meetings)
        vm.askText = ""
        askFocused = false

        let conv = ChatConversation(meetingsContext: context)
        modelContext.insert(conv)
        chatConversation = conv
        chatInitialPrompt = text
        showChat = true
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

// MARK: - Floating Bar

private extension HomeView {
    var floatingBar: some View {
        VStack(spacing: 0) {
            // Gradient fade — no background behind this, so .clear shows List content
            LinearGradient(
                colors: [.clear, AppTheme.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 20)
            .allowsHitTesting(false)

            // Bar content — opaque background
            VStack(alignment: .leading, spacing: 10) {
                if askFocused {
                    PromptsTray(prompts: Prompt.home) { p in
                        navigateToChat(prompt: p.prompt)
                    }
                    .transition(
                            .asymmetric(
                                insertion: .push(from: .bottom).combined(with: .opacity),
                                removal: .push(from: .top).combined(with: .opacity)
                            )
                        )
                }

                HStack(spacing: 10) {
                    AskBar(
                        text: $vm.askText,
                        isAsking: $vm.isAsking,
                        focus: $askFocused,
                        placeholder: "Ask anything",
                        onSend: { navigateToChat(prompt: vm.askText) }
                    )

                    if !askFocused {
                        Button { createQuickNote() } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(AppTheme.accent))
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.surfaceStroke, lineWidth: 1)
                                        .blendMode(.overlay)
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 16)
            .background(AppTheme.background)
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: askFocused)
    }

}
