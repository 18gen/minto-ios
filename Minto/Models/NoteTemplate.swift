import Foundation

enum NoteTemplate: String, CaseIterable, Identifiable {
    case auto
    case oneOnOne
    case customerDiscovery
    case hiring
    case standUp
    case weeklyTeam
    case soap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .oneOnOne: "1 to 1"
        case .customerDiscovery: "Customer: Discovery"
        case .hiring: "Hiring"
        case .standUp: "Stand-Up"
        case .weeklyTeam: "Weekly Team Meeting"
        case .soap: "SOAP"
        }
    }

    var icon: String {
        switch self {
        case .auto: "sparkles"
        case .oneOnOne: "person.2.fill"
        case .customerDiscovery: "building.2.fill"
        case .hiring: "briefcase.fill"
        case .standUp: "figure.stand"
        case .weeklyTeam: "calendar"
        case .soap: "cross.case.fill"
        }
    }

    /// Format-specific instructions for the AI enhancement prompt.
    var formatInstruction: String {
        switch self {
        case .auto:
            return ""
        case .oneOnOne:
            return """
            以下の構造でノートを整理してください：
            ## 議論ポイント
            ## フィードバック（受けた/与えた）
            ## アクションアイテム
            ## フォローアップ
            """
        case .customerDiscovery:
            return """
            以下の構造でノートを整理してください：
            ## 顧客のニーズ
            ## 課題・ペインポイント
            ## 要件
            ## 重要な発言（引用）
            ## ネクストステップ
            """
        case .hiring:
            return """
            以下の構造でノートを整理してください：
            ## 候補者の強み
            ## 懸念点
            ## カルチャーフィット
            ## 技術評価
            ## 総合評価・推薦
            """
        case .standUp:
            return """
            以下の構造でノートを整理してください：
            ## 完了したこと
            ## 今日やること
            ## ブロッカー
            ## メモ
            """
        case .weeklyTeam:
            return """
            以下の構造でノートを整理してください：
            ## 参加者
            ## 各メンバーのアップデート
            ## 決定事項
            ## アクションアイテム
            ## 次回のアジェンダ
            """
        case .soap:
            return """
            SOAP形式でノートを整理してください：
            S:
            O:
            A:
            P:
            """
        }
    }
}
