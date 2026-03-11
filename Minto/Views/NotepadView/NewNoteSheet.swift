import SwiftData
import SwiftUI

struct NewNoteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var meeting: Meeting

    private let coordinator = iOSRecordingCoordinator.shared
    @State private var selectedDetent: PresentationDetent = .fraction(0.7)
    @State private var currentPage: NotePage = .notes
    @FocusState private var isEditing: Bool
    @State private var enhancer = NoteEnhancer()

    var body: some View {
        VStack(spacing: 0) {
            sheetToolbar

            NoteTranscriptPager(currentPage: $currentPage, meeting: meeting, notesFocus: $isEditing) {
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

            Spacer(minLength: 0)

            if let error = coordinator.recordingError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            RecordingBar(meeting: meeting, isEditing: Binding(get: { isEditing }, set: { isEditing = $0 })) {
                endRecording()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
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
                Text(L("button.cancel"))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                Haptic.impact(.light)
                endRecording()
            } label: {
                Text(L("button.done"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(hasContent ? AppTheme.primary : AppTheme.textTertiary)
            }
            .disabled(!hasContent)
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

// MARK: - Computed

private extension NewNoteSheet {
    var hasContent: Bool {
        !meeting.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !meeting.userNotes.isEmpty
            || !meeting.rawTranscript.isEmpty
    }
}

// MARK: - Actions

private extension NewNoteSheet {
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
