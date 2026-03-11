import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var isLoading: Bool
    var recipeLabel: String?
    var recipeTint: AppTheme.PromptTint?

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = .now, isLoading: Bool = false, recipeLabel: String? = nil, recipeTint: AppTheme.PromptTint? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isLoading = isLoading
        self.recipeLabel = recipeLabel
        self.recipeTint = recipeTint
    }
}
