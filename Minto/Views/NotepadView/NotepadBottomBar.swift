import SwiftUI

struct NotepadBottomBar: View {
    @Bindable var meeting: Meeting
    @Binding var currentPage: NotePage
    var isNotepadEditing: Bool = false
    var onDismissKeyboard: (() -> Void)?
    var onOpenChat: ((_ text: String, _ recipeLabel: String?, _ recipeTint: AppTheme.PromptTint?) -> Void)?

    private let coordinator = iOSRecordingCoordinator.shared
    @State private var askText = ""
    @State private var isAsking = false
    @FocusState private var askFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            recordingStatus

            FloatingBar(
                prompts: Prompt.notepad,
                askText: $askText,
                isAsking: $isAsking,
                askFocus: $askFocused,
                onSend: {
                    let text = askText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    askText = ""
                    askFocused = false
                    onOpenChat?(text, nil, nil)
                },
                onPromptSelect: { p in
                    askFocused = false
                    onOpenChat?(p.prompt, p.label, p.tint)
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
}
