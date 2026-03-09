import SwiftData
import SwiftUI

struct AIChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: AIChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var isAtBottom = true
    @State private var showDrawer = false

    private let initialPrompt: String?

    init(conversation: ChatConversation, initialPrompt: String? = nil) {
        self._vm = StateObject(wrappedValue: AIChatViewModel(conversation: conversation))
        self.initialPrompt = initialPrompt
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main chat content
            NavigationStack {
                chatContent
                    .navigationTitle(vm.conversation.title == "New Chat" ? "AI Assistant" : vm.conversation.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                Haptic.impact(.light)
                                toggleDrawer()
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
            .offset(x: showDrawer ? 280 : 0)
            .overlay {
                if showDrawer {
                    Color.white.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture { toggleDrawer() }
                }
            }

            // Drawer
            if showDrawer {
                ChatDrawerView(
                    currentConversation: vm.conversation,
                    onSelect: { conv in
                        vm.switchConversation(conv)
                        toggleDrawer()
                    },
                    onNewChat: {
                        createNewChat()
                        toggleDrawer()
                    }
                )
                .transition(.move(edge: .leading))
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showDrawer)
        .gesture(drawerDragGesture)
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
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, AppTheme.background],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)

                    AskBar(
                        text: $vm.inputText,
                        isAsking: $vm.isResponding,
                        focus: $inputFocused,
                        placeholder: "Follow up...",
                        onSend: {
                            Haptic.impact(.light)
                            let text = vm.inputText
                            inputFocused = false
                            vm.inputText = ""
                            Task { await vm.sendMessage(text) }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 5)
                    .padding(.bottom, 10)
                    .background(AppTheme.background)
                }
            }
            .overlay(alignment: .bottom) {
                if !isAtBottom {
                    Button {
                        Haptic.impact(.light)
                        scrollToBottom(proxy)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.surfaceFill)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 70)
                    .transition(.scale.combined(with: .opacity))
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

    private func toggleDrawer() {
        showDrawer.toggle()
        if showDrawer { inputFocused = false }
    }

    private func createNewChat() {
        let conv = ChatConversation(meetingsContext: vm.conversation.meetingsContext)
        modelContext.insert(conv)
        vm.switchConversation(conv)
    }

    private var drawerDragGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width > 80, !showDrawer {
                    toggleDrawer()
                } else if value.translation.width < -80, showDrawer {
                    toggleDrawer()
                }
            }
    }
}
