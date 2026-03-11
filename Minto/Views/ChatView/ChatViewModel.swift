import SwiftUI

@Observable @MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isResponding = false

    private(set) var conversation: ChatConversation
    private let claudeService = ClaudeService.shared

    private var systemPrompt: String {
        let context = conversation.meetingsContext
        return switch AppSettings.shared.language {
        case .ja:
            """
            あなたは会議アシスタントです。ユーザーの会議メモと文字起こしを元に、質問に簡潔かつ正確に回答してください。
            回答は日本語で、要点を押さえて分かりやすく答えてください。
            情報が不足している場合は、その旨を伝えてください。

            以下はユーザーの最近の会議データです:
            \(context)
            """
        case .en:
            """
            You are a meeting assistant. Answer questions concisely and accurately based on the user's meeting notes and transcript.
            If information is insufficient, let them know.

            Here is the user's recent meeting data:
            \(context)
            """
        }
    }

    init(conversation: ChatConversation) {
        self.conversation = conversation
        self.messages = conversation.messages
    }

    /// Switch to a different conversation (from drawer selection).
    func switchConversation(_ newConversation: ChatConversation) {
        conversation = newConversation
        messages = newConversation.messages
        inputText = ""
        isResponding = false
    }

    func sendInitialPrompt(_ prompt: String, recipeLabel: String? = nil, recipeTint: Tint? = nil) async {
        guard !messages.contains(where: { $0.role == .assistant }) else { return }
        if !messages.isEmpty {
            messages.removeAll()
            persistMessages()
        }
        await send(prompt, recipeLabel: recipeLabel, recipeTint: recipeTint)
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await send(trimmed)
    }

    func sendRecipe(_ prompt: Prompt) async {
        inputText = ""
        await send(prompt.prompt, recipeLabel: prompt.label, recipeTint: prompt.tint)
    }

    private func send(_ text: String, recipeLabel: String? = nil, recipeTint: Tint? = nil) async {
        let userMsg = ChatMessage(role: .user, content: text, recipeLabel: recipeLabel, recipeTint: recipeTint)
        messages.append(userMsg)

        // Auto-title from first user message
        if conversation.title == "New Chat" {
            conversation.title = String(text.prefix(40))
        }

        let thinkingId = UUID()
        let thinkingMsg = ChatMessage(id: thinkingId, role: .assistant, content: "", isLoading: true)
        messages.append(thinkingMsg)
        isResponding = true

        // Save user message immediately
        persistMessages()

        let apiMessages = messages
            .filter { !$0.isLoading }
            .map { ["role": $0.role.rawValue, "content": $0.content] }

        do {
            let answer = try await claudeService.chat(
                systemPrompt: systemPrompt,
                messages: apiMessages
            )
            if let idx = messages.firstIndex(where: { $0.id == thinkingId }) {
                messages[idx].content = answer
                messages[idx].isLoading = false
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == thinkingId }) {
                messages[idx].content = "Error: \(error.localizedDescription)"
                messages[idx].isLoading = false
            }
        }

        isResponding = false
        persistMessages()
    }

    private func persistMessages() {
        conversation.messages = messages.filter { !$0.isLoading }
    }
}
