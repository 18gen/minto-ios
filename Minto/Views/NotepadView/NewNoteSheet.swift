import SwiftData
import SwiftUI

struct NewNoteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var meeting: Meeting

    private let coordinator = iOSRecordingCoordinator.shared
    @State private var recordingPhase: RecordingPhase = .idle
    @State private var elapsedSeconds: Int = 0
    @State private var selectedDetent: PresentationDetent = .fraction(0.7)
    @State private var currentPage: NotePage = .notes
    @FocusState private var isEditing: Bool

    enum RecordingPhase { case idle, recording, paused }

    var body: some View {
        VStack(spacing: 0) {
            sheetToolbar

            NoteTranscriptPager(currentPage: $currentPage, meeting: meeting) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("New Note", text: $meeting.title)
                            .textFieldStyle(.automatic)
                            .font(.system(.title, design: .serif))
                            .padding(.horizontal, 16)
                            .focused($isEditing)

                        notesEditor
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 8)
                }
            }

            Spacer(minLength: 0)

            if let error = coordinator.recordingError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            recordingBar
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(AppTheme.inputFill)
        .presentationDetents([.fraction(0.7), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(AppTheme.inputFill)
        .presentationContentInteraction(.scrolls)
        .onChange(of: isEditing) { _, focused in
            if focused { selectedDetent = .large }
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage == .notes { isEditing = true }
        }
        .task(id: recordingPhase) {
            guard recordingPhase == .recording else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                    elapsedSeconds = Int(coordinator.totalElapsedSeconds)
                } catch {
                    break
                }
            }
        }
        .task {
            // Auto-start recording if enabled in settings
            if AppSettings.shared.autoRecord, recordingPhase == .idle {
                startRecording()
            }
        }
    }
}

// MARK: - Subviews

private extension NewNoteSheet {
    var sheetToolbar: some View {
        HStack {
            Button {
                Haptic.impact(.light)
                cancelNote()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                Haptic.impact(.light)
                endRecording()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    var notesEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $meeting.userNotes)
                .font(.system(size: 17))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .focused($isEditing)

            if meeting.userNotes.isEmpty {
                Text("Write notes here...")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Recording Bar

private extension NewNoteSheet {
    var recordingBar: some View {
        Group {
            switch recordingPhase {
            case .idle: idleBar
            case .recording: activeBar
            case .paused: pausedBar
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: recordingPhase)
    }

    var idleBar: some View {
        HStack {
            CapsuleButton("Start Recording", icon: "waveform", style: .cream, fullWidth: true, iconWeight: .regular) {
                Haptic.impact(.medium)
                startRecording()
            }
            if isEditing {
                CapsuleButton(icon: "keyboard.chevron.compact.down", style: .darkOutline) {
                    Haptic.impact(.medium)
                    isEditing = false
                }
            }
        }
    }

    var activeBar: some View {
        HStack {
            CapsuleButton(icon: "pause.fill", style: .darkOutline) {
                Haptic.impact(.medium)
                pauseRecording()
            }

            Spacer()

            Text(formattedTime)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppTheme.accent)

            Spacer()

            endOrDismissKeyboardButton
        }
    }

    var pausedBar: some View {
        HStack {
            CapsuleButton(icon: "play.fill", style: .darkOutline) {
                Haptic.impact(.medium)
                resumeRecording()
            }

            Spacer()

            endOrDismissKeyboardButton
        }
    }

    @ViewBuilder
    var endOrDismissKeyboardButton: some View {
        if isEditing {
            CapsuleButton(icon: "keyboard.chevron.compact.down", style: .darkOutline) {
                Haptic.impact(.medium)
                isEditing = false
            }
        } else {
            CapsuleButton("End", style: .cream) {
                Haptic.impact(.medium)
                endRecording()
            }
        }
    }
}

// MARK: - Computed

private extension NewNoteSheet {
    var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Actions

private extension NewNoteSheet {
    func startRecording() {
        Task {
            await coordinator.startRecording(meeting: meeting)
            if coordinator.isRecording {
                recordingPhase = .recording
            }
        }
    }

    func pauseRecording() {
        Task {
            await coordinator.pauseRecording()
            elapsedSeconds = Int(coordinator.totalElapsedSeconds)
            recordingPhase = .paused
        }
    }

    func resumeRecording() {
        Task {
            await coordinator.startRecording(meeting: meeting)
            if coordinator.isRecording {
                recordingPhase = .recording
            }
        }
    }

    func endRecording() {
        Task {
            await coordinator.stopRecording()
            dismiss()
        }
    }

    func cancelNote() {
        Task {
            await coordinator.stopRecording()
            modelContext.delete(meeting)
            try? modelContext.save()
            dismiss()
        }
    }
}
