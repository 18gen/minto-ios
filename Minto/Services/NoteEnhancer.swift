import Foundation
import Observation

@Observable @MainActor
final class NoteEnhancer {
    var isAugmenting = false
    var augmentError: String?
    var showingEnhanced = false

    func enhance(meeting: Meeting, template: NoteTemplate) {
        guard !meeting.rawTranscript.isEmpty, !isAugmenting else { return }
        let needsTitle = meeting.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isAugmenting = true
        augmentError = nil
        Task {
            do {
                let result = try await ClaudeService.shared.enhanceNotes(
                    userNotes: meeting.userNotes,
                    transcript: meeting.rawTranscript,
                    template: template,
                    language: AppSettings.shared.language,
                    needsTitle: needsTitle
                )

                if needsTitle, let separatorRange = result.range(of: "\n\n") {
                    let title = String(result[result.startIndex..<separatorRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let notes = String(result[separatorRange.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        meeting.title = title
                    }
                    meeting.augmentedNotes = notes.isEmpty ? result : notes
                } else {
                    meeting.augmentedNotes = result
                }

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
