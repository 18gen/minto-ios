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
        title: String = "",
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

// MARK: - Grouping

struct ConversationGroup {
    let label: String
    let conversations: [ChatConversation]
}

extension ChatConversation {
    static func grouped(_ conversations: [ChatConversation]) -> [ConversationGroup] {
        let calendar = Calendar.current
        let now = Date.now

        var today: [ChatConversation] = []
        var yesterday: [ChatConversation] = []
        var thisWeek: [ChatConversation] = []
        var older: [ChatConversation] = []

        for conv in conversations {
            if calendar.isDateInToday(conv.updatedAt) {
                today.append(conv)
            } else if calendar.isDateInYesterday(conv.updatedAt) {
                yesterday.append(conv)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      conv.updatedAt > weekAgo
            {
                thisWeek.append(conv)
            } else {
                older.append(conv)
            }
        }

        var groups: [ConversationGroup] = []
        if !today.isEmpty { groups.append(.init(label: L("group.today"), conversations: today)) }
        if !yesterday.isEmpty { groups.append(.init(label: L("group.yesterday"), conversations: yesterday)) }
        if !thisWeek.isEmpty { groups.append(.init(label: L("group.thisWeek"), conversations: thisWeek)) }
        if !older.isEmpty { groups.append(.init(label: L("group.older"), conversations: older)) }
        return groups
    }
}
