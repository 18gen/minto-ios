import SwiftData

enum ChatFactory {
    static func recentContext(from meetings: [Meeting], limit: Int = 5) -> String {
        meetings.prefix(limit).map {
            "Meeting: \($0.title)\nNotes: \($0.userNotes)\nTranscript: \($0.rawTranscript)"
        }
        .joined(separator: "\n---\n")
    }

    @discardableResult
    static func makePresentation(
        in context: ModelContext,
        meetingsContext: String,
        prompt: String? = nil,
        recipeLabel: String? = nil,
        recipeTint: Tint? = nil
    ) -> ChatPresentation {
        let conv = ChatConversation(meetingsContext: meetingsContext)
        context.insert(conv)
        return ChatPresentation(
            conversation: conv,
            initialPrompt: prompt,
            initialRecipeLabel: recipeLabel,
            initialRecipeTint: recipeTint
        )
    }
}
