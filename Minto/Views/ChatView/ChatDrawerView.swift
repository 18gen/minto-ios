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
    @FocusState private var searchFocused: Bool

    private var isSearching: Bool {
        searchFocused || !searchText.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            Divider().opacity(0.3)

            // Conversation list
            if isSearching {
                searchResultsList
            } else if conversations.isEmpty {
                emptyState
            } else {
                groupedList
            }

            // Placeholder for future bottom bar button
            if !isSearching {
                Divider().opacity(0.3)
                Spacer().frame(height: 14)
            }
        }
        .background(AppTheme.background)
        .onChange(of: searchFocused) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearchExpanded = searchFocused
            }
        }
    }
}

// MARK: - Search Bar

private extension ChatDrawerView {
    var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .foregroundStyle(.secondary)

                TextField("Search", text: $searchText)
                    .font(.system(size: 17))
                    .focused($searchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .glassEffect(.regular, in: .capsule)

            if isSearching {
                Button {
                    searchText = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .transition(.scale.combined(with: .opacity))
            } else {
                Button {
                    Haptic.impact(.light)
                    onNewChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearching)
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
                Text(conv.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
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

        return VStack(spacing: 16) {
            Spacer(minLength: 0)
            ForEach(messages) { message in
                ChatBubble(message: message)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(width: 340)
        .frame(maxHeight: 500, alignment: .bottom)
        .clipped()
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
