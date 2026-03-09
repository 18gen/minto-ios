import SwiftData
import SwiftUI

struct ChatDrawerView: View {
    @Query(sort: \ChatConversation.updatedAt, order: .reverse) private var conversations: [ChatConversation]
    @Environment(\.modelContext) private var modelContext

    let currentConversation: ChatConversation?
    let onSelect: (ChatConversation) -> Void
    let onNewChat: () -> Void

    private let drawerWidth: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.3)

            // Conversation list
            if conversations.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No conversations yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        let grouped = groupedConversations
                        ForEach(grouped, id: \.label) { group in
                            Text(group.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            ForEach(group.conversations) { conv in
                                conversationRow(conv)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }

            Divider().opacity(0.3)

            // New Chat button
            Button {
                Haptic.impact(.light)
                onNewChat()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("New Chat")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .frame(width: drawerWidth)
        .background(AppTheme.background)
    }

    @ViewBuilder
    private func conversationRow(_ conv: ChatConversation) -> some View {
        let isActive = conv.persistentModelID == currentConversation?.persistentModelID

        Button {
            Haptic.impact(.light)
            onSelect(conv)
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(relativeTime(conv.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? Color.white.opacity(0.15) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(conv)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Grouping

    private struct ConversationGroup {
        let label: String
        let conversations: [ChatConversation]
    }

    private var groupedConversations: [ConversationGroup] {
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
        if !today.isEmpty { groups.append(.init(label: "Today", conversations: today)) }
        if !yesterday.isEmpty { groups.append(.init(label: "Yesterday", conversations: yesterday)) }
        if !thisWeek.isEmpty { groups.append(.init(label: "This Week", conversations: thisWeek)) }
        if !older.isEmpty { groups.append(.init(label: "Older", conversations: older)) }
        return groups
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
