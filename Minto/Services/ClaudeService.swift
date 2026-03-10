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

    func augmentNotes(userNotes: String, transcript: String, toneMode: String) async throws -> String {
        let systemPrompt = buildAugmentSystemPrompt(toneMode: toneMode)
        let userMessage = buildAugmentUserMessage(userNotes: userNotes, transcript: transcript)
        return try await sendRequest(systemPrompt: systemPrompt, userMessage: userMessage)
    }

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

    private func buildAugmentSystemPrompt(toneMode: String) -> String {
        let toneInstruction = switch toneMode {
        case "casual":
            """
            タメ口（カジュアルな口調）で書いてください。です/ます体は最小限にしてください。
            友達に話すような自然な日本語で書いてください。
            """
        case "formal":
            """
            敬語（尊敬語・謙譲語）を適切に使って書いてください。
            ビジネス上の敬意を持った格式高い文体で書いてください。
            """
        default: // business
            """
            です/ます体で書いてください。ビジネスに適したプロフェッショナルな文体で書いてください。
            """
        }

        return """
        あなたは会議の議事録を整理するアシスタントです。
        ユーザーのメモと会議の文字起こしを元に、構造化された議事録を作成してください。

        \(toneInstruction)

        以下の構造で出力してください：

        ## 会議タイトル
        （内容から適切なタイトルを付けてください）

        ## 参加者
        （文字起こしから判別できる範囲で）

        ## 議題
        - 主要な議題をリスト形式で

        ## 議論内容
        各議題について議論された内容を要約

        ## 決定事項
        - 会議で決定された事項をリスト形式で

        ## アクションアイテム
        - 誰が何をいつまでにやるか

        ## 次のステップ
        - 次回の会議や今後の予定
        """
    }

    private func buildAugmentUserMessage(userNotes: String, transcript: String) -> String {
        var message = ""
        if !userNotes.isEmpty {
            message += "## My Notes\n\(userNotes)\n\n"
        }
        if !transcript.isEmpty {
            message += "## Meeting Transcript\n\(transcript)"
        }
        if message.isEmpty {
            message = "（メモと文字起こしがまだありません）"
        }
        return message
    }
}
