import SwiftUI

struct NotepadBottomBar: View {
    @Bindable var meeting: Meeting
    @Binding var currentPage: NotePage
    var isNotepadEditing: Bool = false
    var onDismissKeyboard: (() -> Void)?

    private let coordinator = iOSRecordingCoordinator.shared
    @State private var askVM = NotepadAskViewModel()
    @FocusState private var askFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            recordingStatus

            FloatingBar(
                prompts: Prompt.notepad,
                askText: $askVM.askText,
                isAsking: $askVM.isAsking,
                askFocus: $askFocused,
                onSend: {
                    Task { await askVM.askQuestion(userNotes: meeting.userNotes, transcript: meeting.rawTranscript) }
                },
                onPromptSelect: { p in
                    askVM.askText = p.prompt
                    askFocused = true
                }
            ) {
                if isNotepadEditing, let onDismissKeyboard {
                    CapsuleButton(icon: "keyboard.chevron.compact.down", style: .darkOutline, size: .compact) {
                        onDismissKeyboard()
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    recordingCapsule
                }
            }
        }
        .sheet(isPresented: $askVM.showAskSheet) {
            askSheetContent
        }
    }

    // MARK: - Recording Status

    @ViewBuilder
    private var recordingStatus: some View {
        VStack(spacing: 6) {
            if let error = coordinator.recordingError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if coordinator.isProcessingBatch {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(coordinator.batchProcessingStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Recording Capsule

    private var recordingCapsule: some View {
        CapsuleButton(
            icon: coordinator.isRecording ? "pause.fill" : "play.fill",
            style: coordinator.isRecording ? .cream : .darkOutline,
            size: .compact,
            isLoading: coordinator.isProcessingBatch
        ) {
            Task {
                if coordinator.isRecording {
                    await coordinator.stopRecording()
                } else {
                    await coordinator.startRecording(meeting: meeting)
                }
            }
        }
        .disabled(coordinator.isProcessingBatch)
    }

    // MARK: - Ask Sheet

    private var askSheetContent: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                if askVM.isAsking {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let error = askVM.askError {
                    Text(error).foregroundStyle(.red).font(.caption)
                } else {
                    ScrollView {
                        Text(askVM.askAnswer)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .navigationTitle("Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { askVM.showAskSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
