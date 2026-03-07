import SwiftUI

struct HistorySection: View {
    let meetings: [Meeting]
    let onSelect: (Meeting) -> Void
    var onDelete: ((Meeting) -> Void)?

    var body: some View {
        let pastMeetings = meetings.filter { $0.status != "recording" }
        let grouped = Dictionary(grouping: pastMeetings) { Calendar.current.startOfDay(for: $0.startDate) }
        let dates = grouped.keys.sorted(by: >)

        ForEach(dates, id: \.self) { date in
            Section {
                ForEach(grouped[date] ?? []) { meeting in
                    meetingRow(meeting)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDelete?(meeting)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                }
            } header: {
                Text(DateHeaderFormatter.string(date))
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .textCase(nil)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func meetingRow(_ meeting: Meeting) -> some View {
        Button { onSelect(meeting) } label: {
            HStack(spacing: 14) {
                IconBadge()

                VStack(alignment: .leading, spacing: 1) {
                    Text(meeting.title.isEmpty ? "New Note" : meeting.title)
                        .font(.system(size: 14))
                        .lineLimit(1)

                    Text("Me")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(meeting.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
