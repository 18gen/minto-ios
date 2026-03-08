import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var askText = ""
    @Published var isAsking = false

    static let quickPrompts: [QuickPrompt] = [
        .init(label: "List recent todos", icon: "pencil", prompt: "Please list all action items and todos from these recent meetings"),
        .init(label: "Summarize meetings", icon: "doc.text", prompt: "Please summarize my recent meetings into key points"),
        .init(label: "Write weekly recap", icon: "calendar", prompt: "Write a weekly recap based on my recent meetings"),
    ]

    func onAppear() async {}

    static func recentContext(from meetings: [Meeting], limit: Int = 5) -> String {
        meetings.prefix(limit).map {
            "Meeting: \($0.title)\nNotes: \($0.userNotes)\nTranscript: \($0.rawTranscript)"
        }
        .joined(separator: "\n---\n")
    }
}
