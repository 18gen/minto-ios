import SwiftData
import SwiftUI

private struct SettingsRoute: Hashable {}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.startDate, order: .reverse) private var meetings: [Meeting]
    @State private var navigationPath = NavigationPath()
    @State private var askText = ""
    @FocusState private var askFocused: Bool

    @State private var showNewNoteSheet = false
    @State private var sheetMeeting: Meeting?
    @State private var sheetAutoStart = false
    @State private var chatPresentation: ChatPresentation?
    @State private var showChatDrawer = false
    @State private var isChatSearchExpanded = false

    private let callDetection = CallDetectionService.shared
    private let coordinator = iOSRecordingCoordinator.shared

    var body: some View {
        DrawerContainer(isOpen: $showChatDrawer, isExpanded: $isChatSearchExpanded) {
            ChatDrawerView(
                currentConversation: nil,
                onSelect: { conv in
                    showChatDrawer = false
                    chatPresentation = ChatPresentation(conversation: conv, initialPrompt: nil, initialRecipeLabel: nil, initialRecipeTint: nil)
                },
                onNewChat: {
                    showChatDrawer = false
                    let context = ChatFactory.recentContext(from: meetings)
                    chatPresentation = ChatFactory.makePresentation(in: modelContext, meetingsContext: context)
                },
                isSearchExpanded: $isChatSearchExpanded
            )
        } content: {
            NavigationStack(path: $navigationPath) {
                ZStack(alignment: .bottom) {
                    List {
                        if callDetection.isOnCall && !coordinator.isRecording {
                            callBanner
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }

                        if meetings.isEmpty {
                            emptyState
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            HistorySection(meetings: meetings, onSelect: { meeting in
                                guard navigationPath.isEmpty else { return }
                                navigationPath.append(meeting)
                            }, onDelete: { meeting in
                                modelContext.delete(meeting)
                                try? modelContext.save()
                            })
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 12)
                    .contentMargins(.bottom, 120)
                    .onTapGesture { askFocused = false }

                    FloatingBar(
                        prompts: Prompt.home(for: AppSettings.shared.language),
                        askText: $askText,
                        isAsking: .constant(false),
                        askFocus: $askFocused,
                        onSend: { navigateToChat(prompt: askText) },
                        onPromptSelect: { navigateToChat(prompt: $0.prompt, recipeLabel: $0.label, recipeTint: $0.tint) }
                    ) {
                        // Record button — primary action
                        Button { startNewRecording() } label: {
                            Image(systemName: "waveform")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.black)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(AppTheme.ctaFill))
                        }
                    }
                }
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle(L("nav.home"))
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
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button { createQuickNote() } label: {
                            Image(systemName: "square.and.pencil")
                        }
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
                .sheet(isPresented: $showNewNoteSheet, onDismiss: handleSheetDismiss) {
                    if let meeting = sheetMeeting {
                        NewNoteSheet(meeting: meeting, autoStartRecording: sheetAutoStart)
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

    // MARK: - Call Banner

    private var callBanner: some View {
        Button { startNewRecording() } label: {
            HStack(spacing: 10) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14))
                Text(L("call.recordPrompt"))
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "record.circle")
                    .font(.system(size: 16))
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(AppTheme.primary.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)

            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppTheme.textTertiary)

            Text(L("empty.recordFirst"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Text(L("empty.recordDescription"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func startNewRecording() {
        Haptic.impact(.medium)
        let meeting = Meeting(title: "")
        modelContext.insert(meeting)
        try? modelContext.save()
        sheetMeeting = meeting
        sheetAutoStart = true
        showNewNoteSheet = true
    }

    private func createQuickNote() {
        Haptic.impact(.light)
        let meeting = Meeting(title: "")
        modelContext.insert(meeting)
        try? modelContext.save()
        sheetMeeting = meeting
        sheetAutoStart = false
        showNewNoteSheet = true
    }

    private func navigateToChat(prompt: String, recipeLabel: String? = nil, recipeTint: Tint? = nil) {
        Haptic.impact(.light)
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let context = ChatFactory.recentContext(from: meetings)
        askText = ""
        askFocused = false

        chatPresentation = ChatFactory.makePresentation(
            in: modelContext,
            meetingsContext: context,
            prompt: text,
            recipeLabel: recipeLabel,
            recipeTint: recipeTint
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
        sheetAutoStart = false
    }
}
