import SwiftUI

struct FloatingBar<Accessory: View>: View {
    let prompts: [Prompt]
    @Binding var askText: String
    @Binding var isAsking: Bool
    var askFocus: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onPromptSelect: (Prompt) -> Void
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, AppTheme.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 20)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                if askFocus.wrappedValue {
                    PromptsTray(prompts: prompts) { onPromptSelect($0) }
                        .transition(
                            .asymmetric(
                                insertion: .push(from: .bottom).combined(with: .opacity),
                                removal: .push(from: .top).combined(with: .opacity)
                            )
                        )
                }

                HStack(spacing: 10) {
                    AskBar(
                        text: $askText,
                        isAsking: $isAsking,
                        focus: askFocus,
                        placeholder: "Ask anything",
                        onSend: onSend
                    )

                    if !askFocus.wrappedValue {
                        accessory()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 16)
            .background(AppTheme.background)
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: askFocus.wrappedValue)
    }
}
