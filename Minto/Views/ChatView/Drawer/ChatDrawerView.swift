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
    @State private var searchResults: [ChatSearchHelper.SearchResult] = []
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
        .onChange(of: searchText) {
            updateSearchResults()
        }
    }
}

// MARK: - Search Bar

private extension ChatDrawerView {
    var searchBar: some View {
        DrawerSearchBar(
            searchText: $searchText,
            searchFocused: $searchFocused,
            isSearching: isSearching,
            onNewChat: onNewChat
        )
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
                        drawerRow(conv, isActive: conv.persistentModelID == currentConversation?.persistentModelID)
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
                            drawerRow(conv)
                        }
                    }
                    .padding(.bottom, 16)
                }
            } else if searchResults.isEmpty {
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
                        ForEach(searchResults, id: \.conversation.persistentModelID) { result in
                            drawerRow(result.conversation, snippet: result.snippet)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Row Views

private extension ChatDrawerView {
    func drawerRow(_ conv: ChatConversation, snippet: String? = nil, isActive: Bool = false) -> some View {
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
                    ChatSearchHelper.highlightedSnippet(snippet, query: searchText)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(DrawerRowButtonStyle(isActive: isActive))
        .modifier(ConversationContextMenu(conversation: conv, modelContext: modelContext))
    }
}

// MARK: - Row Button Style

private struct DrawerRowButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed
                        ? Color.white.opacity(0.12)
                        : isActive ? Color.white.opacity(0.10) : .clear)
                    .padding(.horizontal, 8)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Search Logic

private extension ChatDrawerView {
    func updateSearchResults() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        // Snapshot message data on main actor to avoid SwiftData threading issues
        let snapshots: [(conv: ChatConversation, title: String, contents: [String])] = conversations.map { conv in
            let msgs = conv.messages.map(\.content)
            return (conv: conv, title: conv.title, contents: msgs)
        }

        searchResults = snapshots.compactMap { snapshot in
            let titleMatch = snapshot.title.localizedCaseInsensitiveContains(query)
            let snippet = ChatSearchHelper.findSnippet(in: snapshot.contents, for: query)

            if titleMatch || snippet != nil {
                return ChatSearchHelper.SearchResult(conversation: snapshot.conv, snippet: snippet)
            }
            return nil
        }
    }
}

// MARK: - Context Menu Modifier

private struct ConversationContextMenu: ViewModifier {
    let conversation: ChatConversation
    let modelContext: ModelContext

    func body(content: Content) -> some View {
        content.contextMenu {
            Button(role: .destructive) {
                modelContext.delete(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } preview: {
            let messages = conversation.messages.filter { !$0.isLoading && !$0.content.isEmpty }

            VStack(spacing: 16) {
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
}
