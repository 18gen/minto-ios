import SwiftUI
import Combine

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isResponding = false

    private let meetingsContext: String
    private let claudeService = ClaudeService.shared

    private var systemPrompt: String {
        """
        あなたは会議アシスタントです。ユーザーの会議メモと文字起こしを元に、質問に簡潔かつ正確に回答してください。
        回答は日本語で、要点を押さえて分かりやすく答えてください。
        情報が不足している場合は、その旨を伝えてください。

        以下はユーザーの最近の会議データです:
        \(meetingsContext)
        """
    }

    init(meetingsContext: String) {
        self.meetingsContext = meetingsContext
    }

    func sendInitialPrompt(_ prompt: String) async {
        await send(prompt)
    }

    func sendFollowUp() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        await send(text)
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await send(trimmed)
    }

    private func send(_ text: String) async {
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)

        let thinkingId = UUID()
        let thinkingMsg = ChatMessage(id: thinkingId, role: .assistant, content: "", isLoading: true)
        messages.append(thinkingMsg)
        isResponding = true

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
    }
}
