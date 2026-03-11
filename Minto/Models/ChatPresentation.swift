import Foundation

struct ChatPresentation: Identifiable {
    let id = UUID()
    let conversation: ChatConversation
    let initialPrompt: String?
    let initialRecipeLabel: String?
    let initialRecipeTint: Tint?
}
