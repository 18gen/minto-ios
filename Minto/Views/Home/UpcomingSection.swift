import SwiftUI

struct UpcomingSection: View {
    let events: [CalendarEvent]
    let isLoading: Bool
    let currentEventID: String?
    let onSelect: (CalendarEvent) -> Void

    @State private var isExpanded = false

    private var groupedByDay: [(Date, [CalendarEvent])] {
        let grouped = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.startDate) }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        if events.isEmpty && !isLoading {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }

                let visibleEvents = isExpanded ? events : Array(events.prefix(3))

                ForEach(visibleEvents) { event in
                    Button { onSelect(event) } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(currentEventID == event.id ? Color.green : AppTheme.accent)
                                .frame(width: 4, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)

                                Text(EventTimeFormatter.string(for: event))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if currentEventID == event.id {
                                Text("Now")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }

                if events.count > 3 {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Text(isExpanded ? "Show less" : "Show \(events.count - 3) more")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }
}
