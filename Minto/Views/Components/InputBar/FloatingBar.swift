import SwiftUI

struct FloatingBar<Accessory: View>: View {
    let prompts: [Prompt]
    @Binding var askText: String
    @Binding var isAsking: Bool
    var askFocus: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onPromptSelect: (Prompt) -> Void
    @ViewBuilder let accessory: () -> Accessory

    @State private var showRecipes = false

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, AppTheme.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 20)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                if askFocus.wrappedValue || showRecipes {
                    PromptsTray(
                        prompts: prompts,
                        onSelect: { prompt in
                            showRecipes = false
                            onPromptSelect(prompt)
                        },
                        showGridButton: true,
                        isExpanded: $showRecipes
                    )
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
        .animation(AppTheme.Anim.springSnappy, value: askFocus.wrappedValue)
        .animation(AppTheme.Anim.spring, value: showRecipes)
        .onChange(of: askText) {
            if askText == "/" {
                showRecipes = true
            } else if !askText.hasPrefix("/") {
                if showRecipes { showRecipes = false }
            }
        }
    }
}
