import Foundation
import Observation

@Observable
@MainActor
final class GoogleCalendarService {
    static let shared = GoogleCalendarService()

    private var refreshTimer: Timer?

    var upcomingEvents: [CalendarEvent] = []
    var currentEvent: CalendarEvent?
    var isLoading = false

    private init() {}

    func refreshEvents() async {
        guard iOSGoogleAuthService.shared.isAuthenticated else {
            upcomingEvents = []
            currentEvent = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await iOSGoogleAuthService.shared.getValidAccessToken()

            let now = Date.now
            let endDate = Calendar.current.date(byAdding: .day, value: 2, to: now)!

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]

            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
            components.queryItems = [
                URLQueryItem(name: "timeMin", value: formatter.string(from: now)),
                URLQueryItem(name: "timeMax", value: formatter.string(from: endDate)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime")
            ]

            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let items = json?["items"] as? [[String: Any]] else { return }

            let events = items.compactMap { item -> CalendarEvent? in
                guard let id = item["id"] as? String,
                      let summary = item["summary"] as? String else { return nil }

                let start = item["start"] as? [String: String]
                let end = item["end"] as? [String: String]

                let isAllDay = start?["date"] != nil

                let startDate: Date
                let endDate: Date

                if let dateTimeStr = start?["dateTime"] {
                    startDate = formatter.date(from: dateTimeStr) ?? now
                } else if let dateStr = start?["date"] {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    startDate = df.date(from: dateStr) ?? now
                } else {
                    return nil
                }

                if let dateTimeStr = end?["dateTime"] {
                    endDate = formatter.date(from: dateTimeStr) ?? startDate
                } else if let dateStr = end?["date"] {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    endDate = df.date(from: dateStr) ?? startDate
                } else {
                    endDate = startDate
                }

                let attendees: [String]
                if let attendeeList = item["attendees"] as? [[String: Any]] {
                    attendees = attendeeList.compactMap { $0["email"] as? String }
                } else {
                    attendees = []
                }

                let conferenceData = item["conferenceData"] as? [String: Any]
                let entryPoints = conferenceData?["entryPoints"] as? [[String: Any]]
                let meetLink = entryPoints?.first(where: { $0["entryPointType"] as? String == "video" })?["uri"] as? String

                return CalendarEvent(
                    id: id,
                    title: summary,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    attendees: attendees,
                    meetLink: meetLink
                )
            }.filter { !$0.isAllDay }

            upcomingEvents = events

            currentEvent = events.first { event in
                event.startDate <= now && event.endDate > now
            }
        } catch {
            print("Calendar refresh error: \(error)")
        }
    }

    func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshEvents()
            }
        }
    }

    func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
