import Foundation

struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let attendees: [String]
    let meetLink: String?
}
