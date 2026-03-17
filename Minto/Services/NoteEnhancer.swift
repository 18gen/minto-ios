import Foundation
import Observation

@Observable @MainActor
final class NoteEnhancer {
    var isAugmenting = false
    var augmentError: String?
    var showingEnhanced = false
    /// Increments each time enhancement completes, so views can recreate editors.
    var enhancementVersion = 0

    func enhance(meeting: Meeting, template: NoteTemplate) {
        guard !meeting.rawTranscript.isEmpty, !isAugmenting else { return }
        isAugmenting = true
        augmentError = nil
        Task {
            do {
                let result = try await ClaudeService.shared.enhanceNotes(
                    userNotes: meeting.userNotes,
                    transcript: meeting.rawTranscript,
                    template: template,
                    language: AppSettings.shared.language
                )
                meeting.augmentedNotes = result
                meeting.augmentedBlocks = Block.parseFromText(result)
                enhancementVersion += 1
                showingEnhanced = true
            } catch {
                augmentError = error.localizedDescription
            }
            isAugmenting = false
        }
    }

    func tapEnhance(meeting: Meeting) {
        if !meeting.augmentedNotes.isEmpty {
            showingEnhanced = true
        } else {
            enhance(meeting: meeting, template: .auto)
        }
    }
}
