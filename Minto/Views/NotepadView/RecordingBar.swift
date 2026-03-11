import SwiftUI

struct RecordingBar: View {
    let meeting: Meeting
    @Binding var isEditing: Bool
    var onEnd: () -> Void

    private let coordinator = iOSRecordingCoordinator.shared
    @State private var recordingPhase: RecordingPhase = .idle
    @State private var elapsedSeconds: Int = 0

    enum RecordingPhase { case idle, recording, paused }

    var body: some View {
        Group {
            switch recordingPhase {
            case .idle: idleBar
            case .recording: activeBar
            case .paused: pausedBar
            }
        }
        .animation(AppTheme.Anim.spring, value: recordingPhase)
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
            if AppSettings.shared.autoRecord, recordingPhase == .idle {
                startRecording()
            }
        }
    }

    // MARK: - Bars

    private var idleBar: some View {
        HStack {
            CapsuleButton(L("button.startRecording"), icon: "waveform", style: .cream, fullWidth: true, iconWeight: .regular) {
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

    private var activeBar: some View {
        HStack {
            CapsuleButton(icon: "pause.fill", style: .darkOutline) {
                Haptic.impact(.medium)
                pauseRecording()
            }

            Spacer()

            Text(TimeFormatting.mmss(elapsedSeconds))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppTheme.accent)

            Spacer()

            endOrDismissKeyboardButton
        }
    }

    private var pausedBar: some View {
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
    private var endOrDismissKeyboardButton: some View {
        if isEditing {
            CapsuleButton(icon: "keyboard.chevron.compact.down", style: .darkOutline) {
                Haptic.impact(.medium)
                isEditing = false
            }
        } else {
            CapsuleButton(L("button.end"), style: .cream) {
                Haptic.impact(.medium)
                onEnd()
            }
        }
    }

    // MARK: - Actions

    private func startRecording() {
        Task {
            await coordinator.startRecording(meeting: meeting)
            if coordinator.isRecording {
                recordingPhase = .recording
            }
        }
    }

    private func pauseRecording() {
        Task {
            await coordinator.pauseRecording()
            elapsedSeconds = Int(coordinator.totalElapsedSeconds)
            recordingPhase = .paused
        }
    }

    private func resumeRecording() {
        Task {
            await coordinator.startRecording(meeting: meeting)
            if coordinator.isRecording {
                recordingPhase = .recording
            }
        }
    }
}
