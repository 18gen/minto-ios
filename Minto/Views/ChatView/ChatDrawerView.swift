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
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
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
                            searchResultRow(result.conversation, snippet: result.snippet)
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
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(DrawerRowButtonStyle(isActive: isActive))
        .modifier(ConversationContextMenu(conversation: conv, modelContext: modelContext))
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
        .buttonStyle(DrawerRowButtonStyle())
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
