import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var isLoading: Bool

    enum Role: String {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = .now, isLoading: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isLoading = isLoading
    }
}
