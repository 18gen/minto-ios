import SwiftData
import SwiftUI

struct NotepadBottomBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting
    @Binding var currentPage: NotePage

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
                recordingCapsule
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
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    currentPage = currentPage == .notes ? .transcript : .notes
                }
            } label: {
                Image(systemName: currentPage == .notes ? "chevron.right" : "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }

            Button {
                Haptic.impact(.medium)
                Task {
                    if coordinator.isRecording {
                        await coordinator.stopRecording()
                    } else {
                        await coordinator.startRecording(meeting: meeting, modelContext: modelContext)
                    }
                }
            } label: {
                Text(coordinator.isRecording ? "Pause" : "Resume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(coordinator.isRecording ? AppTheme.primary : AppTheme.textSecondary)
            }
            .disabled(coordinator.isProcessingBatch)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1).blendMode(.overlay))
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
