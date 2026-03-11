import Foundation

struct Prompt: Identifiable {
    let id = UUID()
    let label: String
    let prompt: String
    let tint: Tint
}

// MARK: - Presets

extension Prompt {
    static func home(for language: AppLanguage) -> [Prompt] {
        switch language {
        case .ja:
            [
                .init(label: "最近のTODOを一覧", prompt: "最近の会議からアクションアイテムとTODOをリストアップしてください", tint: .mint),
                .init(label: "会議を要約", prompt: "最近の会議を要点にまとめてください", tint: .green),
                .init(label: "週次レポートを作成", prompt: "最近の会議に基づいて週次レポートを書いてください", tint: .cyan),
            ]
        case .en:
            [
                .init(label: "List recent todos", prompt: "Please list all action items and todos from these recent meetings", tint: .mint),
                .init(label: "Summarize meetings", prompt: "Please summarize my recent meetings into key points", tint: .green),
                .init(label: "Write weekly recap", prompt: "Write a weekly recap based on my recent meetings", tint: .cyan),
            ]
        }
    }

    static func notepad(for language: AppLanguage) -> [Prompt] {
        switch language {
        case .ja:
            [
                .init(label: "フォローアップメール", prompt: "このノートを元にフォローアップメールを書いてください。", tint: .mint),
                .init(label: "TODOをリスト", prompt: "アクションアイテムとTODOをリストアップしてください。", tint: .green),
                .init(label: "ノートを詳細に", prompt: "ノートをより詳細で構造化された形に書き直してください。", tint: .cyan),
            ]
        case .en:
            [
                .init(label: "Write follow up email", prompt: "Write a follow up email based on these notes.", tint: .mint),
                .init(label: "List my todos", prompt: "List all action items and todos.", tint: .green),
                .init(label: "Make notes longer", prompt: "Rewrite notes to be more detailed and structured.", tint: .cyan),
            ]
        }
    }

    static func chat(for language: AppLanguage) -> [Prompt] {
        switch language {
        case .ja:
            [
                .init(label: "チャットを要約", prompt: "この会話の内容を簡潔にまとめてください。", tint: .mint),
                .init(label: "アクションアイテム", prompt: "この会話からアクションアイテムとTODOをリストアップしてください。", tint: .green),
                .init(label: "フォローアップメール", prompt: "この会話の内容を元にフォローアップメールを書いてください。", tint: .cyan),
                .init(label: "英語に翻訳", prompt: "この会話の内容を英語に翻訳してください。", tint: .mint),
                .init(label: "詳しく説明", prompt: "最後の回答についてもっと詳しく説明してください。", tint: .green),
            ]
        case .en:
            [
                .init(label: "Summarize chat", prompt: "Summarize this conversation concisely.", tint: .mint),
                .init(label: "List action items", prompt: "List all action items and TODOs from this conversation.", tint: .green),
                .init(label: "Write follow-up email", prompt: "Write a follow-up email based on this conversation.", tint: .cyan),
                .init(label: "Translate to Japanese", prompt: "Translate the content of this conversation to Japanese.", tint: .mint),
                .init(label: "Explain in detail", prompt: "Explain the last response in more detail.", tint: .green),
            ]
        }
    }
}
