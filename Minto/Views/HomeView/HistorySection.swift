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
                    Button { onSelect(meeting) } label: {
                        meetingRow(meeting)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Haptic.notification(.warning)
                            onDelete?(meeting)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(DateHeaderFormatter.string(date))
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
            .headerProminence(.increased)
        }
    }

    private func meetingRow(_ meeting: Meeting) -> some View {
        HStack(spacing: 12) {
            IconBadge(
                icon: hasTranscript(meeting) ? "waveform" : "doc.text",
                tint: hasTranscript(meeting) ? AppTheme.accent : .secondary
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title.isEmpty ? "New Note" : meeting.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 0) {
                    Text(meeting.startDate.formatted(date: .omitted, time: .shortened))

                    if let dur = formattedDuration(meeting) {
                        Text("  \(dur)")
                    }

                    if let sub = subtitle(for: meeting) {
                        Text("  \(sub)")
                            .lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    // MARK: - Helpers

    private func hasTranscript(_ meeting: Meeting) -> Bool {
        !meeting.rawTranscript.isEmpty || !meeting.segments.isEmpty
    }

    private func subtitle(for meeting: Meeting) -> String? {
        let notes = meeting.userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            return notes.components(separatedBy: .newlines).first
        }
        if hasTranscript(meeting) {
            return "Transcript available"
        }
        return nil
    }

    private func formattedDuration(_ meeting: Meeting) -> String? {
        guard let end = meeting.endDate else { return nil }
        let seconds = Int(end.timeIntervalSince(meeting.startDate))
        guard seconds > 0 else { return nil }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }
}
