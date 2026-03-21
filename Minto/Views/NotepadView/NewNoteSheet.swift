import SwiftData
import SwiftUI

struct NewNoteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var meeting: Meeting
    var autoStartRecording: Bool = false

    private let coordinator = iOSRecordingCoordinator.shared
    @State private var selectedDetent: PresentationDetent = .fraction(0.7)
    @State private var currentPage: NotePage = .notes
    @FocusState private var isEditing: Bool
    @State private var enhancer = NoteEnhancer()
    @State private var sheetPhase: SheetPhase = .editing

    enum SheetPhase: Equatable {
        case editing
        case processing
        case enhancing
        case complete
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetToolbar

            if sheetPhase == .editing {
                editingContent
            } else {
                processingContent
            }

            Spacer(minLength: 0)

            if sheetPhase == .editing {
                if let error = coordinator.recordingError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                RecordingBar(meeting: meeting, isEditing: Binding(get: { isEditing }, set: { isEditing = $0 }), autoStart: autoStartRecording) {
                    endRecording()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(AppTheme.surface)
        .presentationDetents([.fraction(0.7), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(AppTheme.surface)
        .presentationContentInteraction(.scrolls)
        .onChange(of: isEditing) { _, focused in
            if focused { selectedDetent = .large }
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage == .notes { isEditing = true }
        }
        .onChange(of: meeting.status) { _, newStatus in
            if newStatus == "done", sheetPhase == .processing {
                triggerEnhancement()
            }
        }
        .onChange(of: enhancer.isAugmenting) { _, isAugmenting in
            if !isAugmenting, sheetPhase == .enhancing {
                if !meeting.augmentedNotes.isEmpty {
                    withAnimation(AppTheme.Anim.spring) {
                        sheetPhase = .complete
                    }
                    Haptic.notification(.success)
                } else if enhancer.augmentError != nil {
                    // Enhancement failed — still show as complete so user can dismiss
                    sheetPhase = .complete
                }
            }
        }
    }
}

// MARK: - Editing Content

private extension NewNoteSheet {
    var editingContent: some View {
        NoteTranscriptPager(currentPage: $currentPage, meeting: meeting, onClearFocus: {
            isEditing = false
        }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NoteHeaderView(meeting: meeting, enhancer: enhancer)
                        .focused($isEditing)
                        .padding(.horizontal, 16)

                    if enhancer.showingEnhanced && !meeting.augmentedNotes.isEmpty {
                        TextEditor(text: $meeting.augmentedNotes)
                            .font(.system(size: 17))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .focused($isEditing)
                            .padding(.horizontal, 12)
                    } else {
                        notesEditor
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    var notesEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $meeting.userNotes)
                .font(.system(size: 17))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .focused($isEditing)

            if meeting.userNotes.isEmpty {
                Text(L("placeholder.writeNotes"))
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Processing Content

private extension NewNoteSheet {
    var processingContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress steps
                VStack(alignment: .leading, spacing: 16) {
                    progressStep(L("status.recordingSaved"), isComplete: true)
                    progressStep(L("status.analyzingSpeakers"), isComplete: sheetPhase != .processing)
                    progressStep(L("status.generatingSummary"), isComplete: sheetPhase == .complete)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)

                // Summary card (when complete)
                if sheetPhase == .complete, !meeting.augmentedNotes.isEmpty {
                    VStack(spacing: 16) {
                        Text(meeting.augmentedNotes)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(AppTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        HStack(spacing: 12) {
                            CapsuleButton(L("button.copy"), icon: "doc.on.doc", style: .cream, fullWidth: true) {
                                copyFormattedSummary()
                            }

                            ShareLink(item: formattedShareText) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text(L("button.share"))
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Capsule().fill(AppTheme.surface))
                                .overlay(Capsule().stroke(AppTheme.surfaceStroke, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Error display
                if let error = enhancer.augmentError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    func progressStep(_ label: String, isComplete: Bool) -> some View {
        HStack(spacing: 12) {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.primary)
                    .font(.system(size: 20))
            } else {
                ProgressView()
                    .frame(width: 20, height: 20)
            }

            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(isComplete ? .primary : .secondary)
        }
    }
}

// MARK: - Toolbar

private extension NewNoteSheet {
    var sheetToolbar: some View {
        HStack {
            Button {
                Haptic.impact(.light)
                cancelNote()
            } label: {
                Text(L("button.cancel"))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                Haptic.impact(.light)
                if sheetPhase == .complete || sheetPhase == .editing {
                    endRecording()
                }
            } label: {
                Text(L("button.done"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(doneButtonColor)
            }
            .disabled(!canDismiss)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Computed

private extension NewNoteSheet {
    var hasContent: Bool {
        !meeting.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !meeting.userNotes.isEmpty
            || !meeting.rawTranscript.isEmpty
    }

    var canDismiss: Bool {
        switch sheetPhase {
        case .editing: hasContent || !coordinator.isRecording
        case .complete: true
        case .processing, .enhancing: false
        }
    }

    var doneButtonColor: Color {
        switch sheetPhase {
        case .editing: hasContent ? AppTheme.primary : AppTheme.textTertiary
        case .complete: AppTheme.primary
        case .processing, .enhancing: AppTheme.textTertiary
        }
    }

    var formattedShareText: String {
        var parts: [String] = []
        let title = meeting.title.isEmpty ? L("placeholder.newNote") : meeting.title
        let date = meeting.startDate.formatted(date: .abbreviated, time: .shortened)
        parts.append("📝 \(title) (\(date))")
        if !meeting.augmentedNotes.isEmpty {
            parts.append(meeting.augmentedNotes)
        } else if !meeting.userNotes.isEmpty {
            parts.append(meeting.userNotes)
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Actions

private extension NewNoteSheet {
    func endRecording() {
        guard coordinator.isRecording || coordinator.currentMeeting != nil else {
            dismiss()
            return
        }

        if sheetPhase == .complete {
            dismiss()
            return
        }

        Task {
            await coordinator.stopRecording()

            if coordinator.isProcessingBatch {
                selectedDetent = .large
                withAnimation(AppTheme.Anim.spring) {
                    sheetPhase = .processing
                }
            } else if !meeting.rawTranscript.isEmpty {
                selectedDetent = .large
                triggerEnhancement()
            } else {
                dismiss()
            }
        }
    }

    func triggerEnhancement() {
        withAnimation(AppTheme.Anim.spring) {
            sheetPhase = .enhancing
        }
        enhancer.enhance(meeting: meeting, template: .auto)
    }

    func copyFormattedSummary() {
        UIPasteboard.general.string = formattedShareText
        Haptic.notification(.success)
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
