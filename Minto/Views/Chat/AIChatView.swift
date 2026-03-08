import SwiftUI

struct ChatDestination: Hashable {
    let initialPrompt: String
    let meetingsContext: String
}

struct AIChatView: View {
    let initialPrompt: String
    let meetingsContext: String

    @StateObject private var vm: AIChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var isAtBottom = true

    init(initialPrompt: String, meetingsContext: String) {
        self.initialPrompt = initialPrompt
        self.meetingsContext = meetingsContext
        self._vm = StateObject(wrappedValue: AIChatViewModel(meetingsContext: meetingsContext))
    }

    var body: some View {
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
                DispatchQueue.main.async {
                    scrollToBottom(proxy)
                }
            }
            .onChange(of: vm.messages.last?.isLoading) {
                DispatchQueue.main.async {
                    scrollToBottom(proxy)
                }
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
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.sendInitialPrompt(initialPrompt)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard !vm.messages.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom")
        }
    }
}
