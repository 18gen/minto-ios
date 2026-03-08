import SwiftUI
import SwiftData

struct HomeTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.startDate, order: .reverse) private var meetings: [Meeting]
    @State private var navigationPath = NavigationPath()
    @StateObject private var vm = HomeViewModel()
    @FocusState private var askFocused: Bool

    @State private var showSettings = false
    @State private var showNewNoteSheet = false
    @State private var sheetMeeting: Meeting?

    var body: some View {
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsTab()
            }
            .navigationDestination(for: Meeting.self) { meeting in
                NotepadView(meeting: meeting)
            }
            .navigationDestination(for: ChatDestination.self) { dest in
                AIChatView(initialPrompt: dest.initialPrompt, meetingsContext: dest.meetingsContext)
            }
            .task { await vm.onAppear() }
            .sheet(isPresented: $showNewNoteSheet, onDismiss: handleSheetDismiss) {
                if let meeting = sheetMeeting {
                    NewNoteSheet(meeting: meeting)
                }
            }
        }
    }

    private func createQuickNote() {
        let meeting = Meeting(title: "")
        modelContext.insert(meeting)
        try? modelContext.save()
        sheetMeeting = meeting
        showNewNoteSheet = true
    }

    private func navigateToChat(prompt: String) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let context = HomeViewModel.recentContext(from: meetings)
        vm.askText = ""
        askFocused = false
        navigationPath.append(ChatDestination(initialPrompt: text, meetingsContext: context))
    }

    private func handleSheetDismiss() {
        guard let meeting = sheetMeeting else { return }

        let coordinator = iOSRecordingCoordinator.shared
        if coordinator.isRecording {
            Task { await coordinator.stopRecording() }
        }

        let titleEmpty = meeting.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if titleEmpty && meeting.userNotes.isEmpty && meeting.rawTranscript.isEmpty {
            modelContext.delete(meeting)
            try? modelContext.save()
        }

        sheetMeeting = nil
    }
}

// MARK: - Floating Bar

private extension HomeTab {
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
            VStack(alignment: .leading, spacing: 0) {
                if askFocused {
                    quickPromptsTray
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

    var quickPromptsTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeViewModel.quickPrompts.prefix(3)) { p in
                    QuickPromptPill(prompt: p) {
                        navigateToChat(prompt: p.prompt)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 5)
        }
    }
}
