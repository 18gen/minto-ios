import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var askText = ""
    @Published var isAsking = false
    @Published var askAnswer = ""
    @Published var showAskResult = false

    let claudeService = ClaudeService.shared
    let calendarService = GoogleCalendarService.shared

    static let quickPrompts: [QuickPrompt] = [
        .init(label: "List recent todos", icon: "pencil", prompt: "Please list all action items and todos from these recent meetings"),
        .init(label: "Summarize meetings", icon: "doc.text", prompt: "Please summarize my recent meetings into key points"),
        .init(label: "Write weekly recap", icon: "calendar", prompt: "Write a weekly recap based on my recent meetings"),
    ]

    func onAppear() async {
        guard iOSGoogleAuthService.shared.isAuthenticated else { return }
        await calendarService.refreshEvents()
        calendarService.startRefreshTimer()
    }

    func ask(meetings: [Meeting], prompt: String) async {
        let q = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isAsking = true
        defer { isAsking = false }

        let context = Self.recentContext(from: meetings)

        do {
            askAnswer = try await claudeService.askQuestion(
                question: q,
                userNotes: context,
                transcript: ""
            )
        } catch {
            askAnswer = "Error: \(error.localizedDescription)"
        }

        showAskResult = true
    }

    func runQuickPrompt(meetings: [Meeting], prompt: QuickPrompt) async {
        askText = prompt.label
        await ask(meetings: meetings, prompt: prompt.prompt)
        askText = ""
    }

    static func recentContext(from meetings: [Meeting], limit: Int = 5) -> String {
        meetings.prefix(limit).map {
            "Meeting: \($0.title)\nNotes: \($0.userNotes)\nTranscript: \($0.rawTranscript)"
        }
        .joined(separator: "\n---\n")
    }
}
