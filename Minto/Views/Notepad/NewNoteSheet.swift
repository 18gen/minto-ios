import SwiftUI
import SwiftData
import UIKit

struct NewNoteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var meeting: Meeting

    @State private var coordinator = iOSRecordingCoordinator.shared
    @State private var recordingPhase: RecordingPhase = .idle
    @State private var elapsedSeconds: Int = 0
    @State private var selectedDetent: PresentationDetent = .fraction(0.7)
    @FocusState private var isEditing: Bool

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    enum RecordingPhase { case idle, recording, paused }

    var body: some View {
        VStack(spacing: 0) {
            sheetToolbar

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
        .onChange(of: isEditing) { _, focused in
            if focused { selectedDetent = .large }
        }
        .task(id: recordingPhase) {
            guard recordingPhase == .recording else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { elapsedSeconds += 1 }
            }
        }
    }
}

// MARK: - Subviews

private extension NewNoteSheet {
    var sheetToolbar: some View {
        HStack {
            HStack(spacing: 16) {
                Button { } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Button { } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    var notesEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $meeting.userNotes)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .focused($isEditing)

            if meeting.userNotes.isEmpty {
                Text("Write notes here...")
                    .font(.system(size: 15))
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
            case .idle:      idleBar
            case .recording: activeBar
            case .paused:    pausedBar
            }
        }
    }

    var idleBar: some View {
        Button {
            haptic.impactOccurred()
            startRecording()
        } label: {
            HStack {
                Image(systemName: "waveform")
                Text("Start Recording")
                    .font(.system(size: 16, weight: .light))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(.white))
        }
        .buttonStyle(.plain)
    }

    var activeBar: some View {
        HStack {
            Button {
                haptic.impactOccurred()
                pauseRecording()
            } label: {
                Text("Pause")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            Spacer()

            AudioWaveformBars(audioLevel: coordinator.currentAudioLevel, isRecording: true)

            Text(formattedTime)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button {
                haptic.impactOccurred()
                cancelRecording()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
    }

    var pausedBar: some View {
        HStack {
            Button {
                haptic.impactOccurred()
                resumeRecording()
            } label: {
                Text("Resume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            Spacer()

            Text("···")
                .foregroundStyle(AppTheme.textTertiary)

            Text(formattedTime)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button {
                haptic.impactOccurred()
                endRecording()
            } label: {
                Text("End")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.8))
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
            await coordinator.startRecording(meeting: meeting, modelContext: modelContext)
            if coordinator.isRecording {
                recordingPhase = .recording
            }
        }
    }

    func pauseRecording() {
        Task {
            await coordinator.stopRecording()
            recordingPhase = .paused
        }
    }

    func resumeRecording() {
        Task {
            await coordinator.startRecording(meeting: meeting, modelContext: modelContext)
            if coordinator.isRecording {
                recordingPhase = .recording
            }
        }
    }

    func cancelRecording() {
        Task {
            await coordinator.stopRecording()
            recordingPhase = .idle
            elapsedSeconds = 0
            meeting.rawTranscript = ""
            meeting.segments.removeAll()
        }
    }

    func endRecording() {
        recordingPhase = .idle
    }
}
