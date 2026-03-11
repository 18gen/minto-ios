import Foundation

struct Prompt: Identifiable {
    let id = UUID()
    let label: String
    let prompt: String
    let tint: Tint
}

// MARK: - Presets

extension Prompt {
    static let home: [Prompt] = [
        .init(label: "List recent todos", prompt: "Please list all action items and todos from these recent meetings", tint: .mint),
        .init(label: "Summarize meetings", prompt: "Please summarize my recent meetings into key points", tint: .green),
        .init(label: "Write weekly recap", prompt: "Write a weekly recap based on my recent meetings", tint: .cyan),
    ]

    static let notepad: [Prompt] = [
        .init(label: "Write follow up email", prompt: "Write a follow up email based on these notes.", tint: .mint),
        .init(label: "List my todos", prompt: "List all action items and todos.", tint: .green),
        .init(label: "Make notes longer", prompt: "Rewrite notes to be more detailed and structured.", tint: .cyan),
    ]

    static let chat: [Prompt] = [
        .init(label: "Summarize chat", prompt: "この会話の内容を簡潔にまとめてください。", tint: .mint),
        .init(label: "List action items", prompt: "この会話からアクションアイテムとTODOをリストアップしてください。", tint: .green),
        .init(label: "Write follow-up email", prompt: "この会話の内容を元にフォローアップメールを書いてください。", tint: .cyan),
        .init(label: "Translate to English", prompt: "この会話の内容を英語に翻訳してください。", tint: .mint),
        .init(label: "Explain in detail", prompt: "最後の回答についてもっと詳しく説明してください。", tint: .green),
    ]
}
