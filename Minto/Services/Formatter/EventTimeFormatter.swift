//
//  EventTimeFormatter.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import Foundation

enum EventTimeFormatter {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static let weekdayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE h:mm a"
        return f
    }()

    static func string(for event: CalendarEvent) -> String {
        let range = "\(time.string(from: event.startDate)) – \(time.string(from: event.endDate))"
        if Calendar.current.isDateInToday(event.startDate) { return range }
        if Calendar.current.isDateInTomorrow(event.startDate) { return "Tomorrow \(time.string(from: event.startDate))" }
        return weekdayTime.string(from: event.startDate)
    }
}
