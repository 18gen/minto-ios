import Foundation

actor ClaudeService {
    static let shared = ClaudeService()

    // swiftlint:disable:next force_unwrapping
    private let endpoint = URL(string: "\(AppSettings.apiProxyBase)/v1/claude")!
    private let model = "claude-sonnet-4-20250514"

    enum ClaudeError: Error, LocalizedError {
        case httpError(Int, String)
        case noContent

        var errorDescription: String? {
            switch self {
            case let .httpError(code, msg): "HTTP \(code): \(msg)"
            case .noContent: "No content in response"
            }
        }
    }

    // MARK: - Public Methods

    func askQuestion(question: String, userNotes: String, transcript: String) async throws -> String {
        let systemPrompt = """
        あなたは会議アシスタントです。ユーザーの会議メモと文字起こしを元に、質問に簡潔かつ正確に回答してください。
        回答は日本語で、要点を押さえて分かりやすく答えてください。
        情報が不足している場合は、その旨を伝えてください。
        """

        var context = "## Question\n\(question)\n\n"
        if !userNotes.isEmpty {
            context += "## My Notes\n\(userNotes)\n\n"
        }
        if !transcript.isEmpty {
            context += "## Meeting Transcript\n\(transcript)"
        }

        return try await sendRequest(systemPrompt: systemPrompt, userMessage: context)
    }

    func suggestTopics(userNotes: String, transcript: String) async throws -> String {
        let systemPrompt = """
        あなたは会議アシスタントです。ユーザーの会議メモと文字起こしを元に、議論すべきトピックを5つ提案してください。
        各トピックは：
        - 会議の内容に関連していること
        - 具体的で実行可能なものであること
        - 簡潔に1〜2文で説明すること

        番号付きリスト形式で日本語で回答してください。
        """

        var context = ""
        if !userNotes.isEmpty {
            context += "## My Notes\n\(userNotes)\n\n"
        }
        if !transcript.isEmpty {
            context += "## Meeting Transcript\n\(transcript)"
        }
        if context.isEmpty {
            context = "（まだメモや文字起こしがありません。一般的な会議トピックを提案してください。）"
        }

        return try await sendRequest(systemPrompt: systemPrompt, userMessage: context)
    }

    func enhanceNotes(userNotes: String, transcript: String, toneMode: String, template: NoteTemplate = .auto) async throws -> String {
        let hasUserNotes = !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let systemPrompt = buildEnhanceSystemPrompt(hasUserNotes: hasUserNotes, toneMode: toneMode, template: template)

        var content = ""
        if hasUserNotes {
            content += "## ユーザーのメモ\n\(userNotes)\n\n"
        }
        content += "## 文字起こし\n\(transcript)"

        return try await sendRequest(systemPrompt: systemPrompt, userMessage: content)
    }

    func correctTranscript(rawTranscript: String) async throws -> String {
        let systemPrompt = """
        あなたは日本語の文字起こし校正アシスタントです。
        音声認識で生成された文字起こしテキストを校正してください。

        修正すべき点：
        - 漢字の誤変換（文脈から正しい漢字を推測）
        - 句読点の追加・修正
        - 英語の技術用語がカタカナ/ひらがなに誤変換されている場合は英語に戻す
        - 明らかな聞き間違いの修正

        変更しない点：
        - 話者の口調や文体
        - 文の意味や内容
        - 話者ラベル（Speaker 0, Speaker 1 等）

        校正後のテキストのみを出力してください。説明は不要です。
        """
        return try await sendRequest(systemPrompt: systemPrompt, userMessage: rawTranscript)
    }

    func chat(systemPrompt: String, messages: [[String: String]]) async throws -> String {
        try await makeRequest(systemPrompt: systemPrompt, messages: messages)
    }

    // MARK: - Private

    private func buildEnhanceSystemPrompt(hasUserNotes: Bool, toneMode: String, template: NoteTemplate) -> String {
        let toneInstruction: String = switch toneMode {
        case "casual": "カジュアルな口調で書いてください。"
        case "formal": "敬語を使った格式高い文体で書いてください。"
        default: "です/ます体で書いてください。"
        }

        let templateInstruction = template.formatInstruction
        if !templateInstruction.isEmpty {
            return """
            あなたはノート作成アシスタントです。
            \(hasUserNotes ? "ユーザーのメモと" : "")会議の文字起こしから、指定された形式でノートを作成してください。
            \(toneInstruction)

            \(templateInstruction)

            ノートのみを出力。説明や前置きは不要。
            """
        } else if hasUserNotes {
            return """
            あなたはノート強化アシスタントです。
            ユーザーが会議中に書いたメモを、文字起こしの内容を使って強化してください。
            \(toneInstruction)

            以下のルール：
            1. ユーザーのメモの構造・箇条書き・順序をできるだけ保つ
            2. 文字起こしから、ユーザーが書き漏らした詳細や文脈を追加する
            3. 曖昧な部分を明確にし、不足情報を補う
            4. ユーザーのメモの言語・トーンに合わせる
            5. 元のメモにない新しいセクションは最小限にする

            強化されたノートのみを出力。説明や前置きは不要。
            """
        } else {
            return """
            あなたはノート作成アシスタントです。
            会議の文字起こしから、構造化されたノートを作成してください。
            \(toneInstruction)

            以下のルール：
            - 重要なポイントを箇条書きでまとめる
            - 決定事項やアクションアイテムがあれば明記する
            - 簡潔で読みやすい形式にする
            - ノートのみを出力。説明や前置きは不要。
            """
        }
    }

    private func sendRequest(systemPrompt: String, userMessage: String) async throws -> String {
        let messages = [["role": "user", "content": userMessage]]
        return try await makeRequest(systemPrompt: systemPrompt, messages: messages)
    }

    private func makeRequest(systemPrompt: String, messages: [[String: String]]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": messages,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.httpError(0, "Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.httpError(httpResponse.statusCode, errorBody)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String
        else {
            throw ClaudeError.noContent
        }
        return text
    }

}
