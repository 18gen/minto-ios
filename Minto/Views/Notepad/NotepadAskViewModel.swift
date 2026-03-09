import SwiftUI

@Observable @MainActor
final class NotepadAskViewModel {
    var askText = ""
    var askAnswer = ""
    var askError: String?
    var isAsking = false
    var showAskSheet = false

    private let claudeService = ClaudeService.shared

    func askQuestion(userNotes: String, transcript: String) async {
        let question = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isAsking = true
        askError = nil
        showAskSheet = true

        do {
            askAnswer = try await claudeService.askQuestion(
                question: question,
                userNotes: userNotes,
                transcript: transcript
            )
        } catch {
            askError = error.localizedDescription
        }

        isAsking = false
    }
}
