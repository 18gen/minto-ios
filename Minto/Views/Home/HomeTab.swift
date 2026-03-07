import SwiftUI
import SwiftData

struct HomeTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.startDate, order: .reverse) private var meetings: [Meeting]
    @State private var navigationPath = NavigationPath()
    @StateObject private var vm = HomeViewModel()
    @FocusState private var askFocused: Bool

    @State private var showNewNoteSheet = false
    @State private var sheetMeeting: Meeting?
    @State private var sheetCalendarEvent: CalendarEvent?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                List {
                    Section {
                        UpcomingSection(
                            events: vm.calendarService.upcomingEvents,
                            isLoading: vm.calendarService.isLoading,
                            currentEventID: vm.calendarService.currentEvent?.id,
                            onSelect: { event in openOrCreateMeeting(for: event) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    }

                    HistorySection(meetings: meetings, onSelect: { meeting in
                        navigationPath.append(meeting)
                    }, onDelete: { meeting in
                        modelContext.delete(meeting)
                        try? modelContext.save()
                    })
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await vm.calendarService.refreshEvents() }
                .contentMargins(.top, 12)
                .contentMargins(.bottom, 120)
                .onTapGesture { askFocused = false }

                floatingBar
            }
            .background(AppTheme.background)
            .navigationTitle("Minto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsTab()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: Meeting.self) { meeting in
                NotepadView(meeting: meeting)
            }
            .task { await vm.onAppear() }
            .sheet(isPresented: $vm.showAskResult) {
                ScrollView {
                    Text(vm.askAnswer)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showNewNoteSheet, onDismiss: handleSheetDismiss) {
                if let meeting = sheetMeeting {
                    NewNoteSheet(meeting: meeting, calendarEvent: sheetCalendarEvent)
                }
            }
        }
    }

    private func createQuickNote() {
        let meeting = Meeting(title: "")
        modelContext.insert(meeting)
        try? modelContext.save()
        sheetMeeting = meeting
        sheetCalendarEvent = nil
        showNewNoteSheet = true
    }

    private func openOrCreateMeeting(for event: CalendarEvent) {
        if let existing = meetings.first(where: { $0.calendarEventID == event.id }) {
            let hasContent = !existing.userNotes.isEmpty || !existing.rawTranscript.isEmpty || !existing.augmentedNotes.isEmpty
            if hasContent {
                navigationPath.append(existing)
            } else {
                sheetMeeting = existing
                sheetCalendarEvent = event
                showNewNoteSheet = true
            }
            return
        }
        let meeting = Meeting(title: event.title)
        meeting.calendarEventID = event.id
        modelContext.insert(meeting)
        try? modelContext.save()
        sheetMeeting = meeting
        sheetCalendarEvent = event
        showNewNoteSheet = true
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
        sheetCalendarEvent = nil
    }
}

// MARK: - Floating Bar

private extension HomeTab {
    var floatingBar: some View {
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
                    onSend: { Task { await vm.ask(meetings: meetings, prompt: vm.askText) } }
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
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 0)
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: askFocused)
    }

    var quickPromptsTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeViewModel.quickPrompts.prefix(3)) { p in
                    QuickPromptPill(prompt: p) {
                        Task { await vm.runQuickPrompt(meetings: meetings, prompt: p) }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 5)
        }
    }
}
