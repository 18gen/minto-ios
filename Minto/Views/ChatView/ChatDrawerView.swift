import SwiftData
import SwiftUI

struct ChatDrawerView: View {
    @Query(sort: \ChatConversation.updatedAt, order: .reverse) private var conversations: [ChatConversation]
    @Environment(\.modelContext) private var modelContext

    let currentConversation: ChatConversation?
    let onSelect: (ChatConversation) -> Void
    let onNewChat: () -> Void
    @Binding var isSearchExpanded: Bool

    @State private var searchText = ""
    @State private var searchActive = false

    private var isSearching: Bool {
        searchActive || !searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Conversation list
                if isSearching {
                    searchResultsList
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    groupedList
                }

                // New Chat button
                if !isSearching {
                    Divider().opacity(0.3)

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
            }
            .background(AppTheme.background)
            .searchable(text: $searchText, isPresented: $searchActive, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onChange(of: searchActive) {
            isSearchExpanded = searchActive
            if !searchActive {
                searchText = ""
            }
        }
    }
}

// MARK: - List Views

private extension ChatDrawerView {
    var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No conversations yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var groupedList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(ChatConversation.grouped(conversations), id: \.label) { group in
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

    var searchResultsList: some View {
        Group {
            if searchText.isEmpty {
                // Focused but no query — show all conversations flat
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(conversations) { conv in
                            conversationRow(conv)
                        }
                    }
                    .padding(.bottom, 16)
                }
            } else {
                let results = searchResults
                if results.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("No results")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(results, id: \.conversation.persistentModelID) { result in
                                searchResultRow(result.conversation, snippet: result.snippet)
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Row Views

private extension ChatDrawerView {
    @ViewBuilder
    func conversationRow(_ conv: ChatConversation) -> some View {
        let isActive = conv.persistentModelID == currentConversation?.persistentModelID

        Button {
            Haptic.impact(.light)
            onSelect(conv)
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.title)
                        .font(.headline)
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
        } preview: {
            conversationPreview(conv)
        }
    }

    @ViewBuilder
    func searchResultRow(_ conv: ChatConversation, snippet: String?) -> some View {
        Button {
            Haptic.impact(.light)
            onSelect(conv)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(conv.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let snippet {
                    highlightedSnippet(snippet, query: searchText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
        } preview: {
            conversationPreview(conv)
        }
    }
}

// MARK: - Context Menu Preview

private extension ChatDrawerView {
    func conversationPreview(_ conv: ChatConversation) -> some View {
        let messages = conv.messages.filter { !$0.isLoading && !$0.content.isEmpty }

        return ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(messages) { message in
                    ChatBubble(message: message)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .defaultScrollAnchor(.bottom)
        .frame(width: 340)
        .background(AppTheme.background)
    }
}

// MARK: - Search Logic

private extension ChatDrawerView {
    struct SearchResult {
        let conversation: ChatConversation
        let snippet: String?
    }

    var searchResults: [SearchResult] {
        let query = searchText
        guard !query.isEmpty else { return [] }

        return conversations.compactMap { conv in
            let titleMatch = conv.title.localizedCaseInsensitiveContains(query)
            let snippet = findSnippet(in: conv, for: query)

            if titleMatch || snippet != nil {
                return SearchResult(conversation: conv, snippet: snippet)
            }
            return nil
        }
    }

    func findSnippet(in conv: ChatConversation, for query: String) -> String? {
        let messages = conv.messages
        for message in messages {
            guard let range = message.content.range(of: query, options: .caseInsensitive) else {
                continue
            }

            let content = message.content
            let matchStart = range.lowerBound
            let matchEnd = range.upperBound

            // Expand context ~40 chars before and after the match
            let contextStart = content.index(matchStart, offsetBy: -40, limitedBy: content.startIndex) ?? content.startIndex
            let contextEnd = content.index(matchEnd, offsetBy: 40, limitedBy: content.endIndex) ?? content.endIndex

            var snippet = String(content[contextStart..<contextEnd])
                .replacingOccurrences(of: "\n", with: " ")

            if contextStart != content.startIndex { snippet = "..." + snippet }
            if contextEnd != content.endIndex { snippet += "..." }

            return snippet
        }
        return nil
    }

    func highlightedSnippet(_ snippet: String, query: String) -> Text {
        guard let range = snippet.range(of: query, options: .caseInsensitive) else {
            return Text(snippet)
        }

        let before = String(snippet[snippet.startIndex..<range.lowerBound])
        let match = String(snippet[range])
        let after = String(snippet[range.upperBound..<snippet.endIndex])

        return Text(before) + Text(match).bold() + Text(after)
    }
}

// MARK: - Helpers

private extension ChatDrawerView {
    func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
