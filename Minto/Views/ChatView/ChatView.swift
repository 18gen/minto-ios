import SwiftData
import SwiftUI

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm: ChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var isAtBottom = true
    @State private var showDrawer = false
    @State private var isSearchExpanded = false

    private let initialPrompt: String?

    init(conversation: ChatConversation, initialPrompt: String? = nil) {
        self._vm = State(wrappedValue: ChatViewModel(conversation: conversation))
        self.initialPrompt = initialPrompt
    }

    var body: some View {
        DrawerContainer(isOpen: $showDrawer, isExpanded: $isSearchExpanded) {
            ChatDrawerView(
                currentConversation: vm.conversation,
                onSelect: { conv in
                    vm.switchConversation(conv)
                    showDrawer = false
                },
                onNewChat: {
                    createNewChat()
                    showDrawer = false
                },
                isSearchExpanded: $isSearchExpanded
            )
        } content: {
            NavigationStack {
                chatContent
                    .navigationTitle(vm.conversation.title == "New Chat" ? "AI Assistant" : vm.conversation.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                Haptic.impact(.light)
                                showDrawer = true
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                Haptic.impact(.light)
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onChange(of: showDrawer) {
            if !showDrawer {
                isSearchExpanded = false
            }
        }
        .task {
            if let prompt = initialPrompt {
                await vm.sendInitialPrompt(prompt)
            }
        }
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                        .onAppear { isAtBottom = true }
                        .onDisappear { isAtBottom = false }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: vm.messages.count) {
                DispatchQueue.main.async { scrollToBottom(proxy) }
            }
            .onChange(of: vm.messages.last?.isLoading) {
                DispatchQueue.main.async { scrollToBottom(proxy) }
            }
            .onTapGesture { inputFocused = false }
            .safeAreaInset(edge: .bottom) {
                FloatingBar(
                    prompts: Prompt.chat,
                    askText: $vm.inputText,
                    isAsking: $vm.isResponding,
                    askFocus: $inputFocused,
                    onSend: {
                        Haptic.impact(.light)
                        let text = vm.inputText
                        inputFocused = false
                        vm.inputText = ""
                        Task { await vm.sendMessage(text) }
                    },
                    onPromptSelect: { prompt in
                        inputFocused = false
                        Task { await vm.sendRecipe(prompt) }
                    }
                ) { EmptyView() }
            }
            .overlay(alignment: .bottom) {
                ScrollToBottomButton(isVisible: !isAtBottom) {
                    scrollToBottom(proxy)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isAtBottom)
        }
        .background(AppTheme.background)
    }

    // MARK: - Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard !vm.messages.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom")
        }
    }

    private func createNewChat() {
        let conv = ChatConversation(meetingsContext: vm.conversation.meetingsContext)
        modelContext.insert(conv)
        vm.switchConversation(conv)
    }
}
