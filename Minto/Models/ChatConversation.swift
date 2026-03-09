import Foundation
import SwiftData

@Model
final class ChatConversation {
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var meetingsContext: String
    var messagesData: Data?

    init(
        title: String = "New Chat",
        meetingsContext: String = "",
        createdAt: Date = .now
    ) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.meetingsContext = meetingsContext
        self.messagesData = nil
    }

    var messages: [ChatMessage] {
        get {
            guard let data = messagesData else { return [] }
            return (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
        }
        set {
            messagesData = try? JSONEncoder().encode(newValue)
            updatedAt = .now
        }
    }
}
