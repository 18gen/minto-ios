import SwiftUI

struct PromptsTray: View {
    let prompts: [Prompt]
    let onSelect: (Prompt) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(prompts.prefix(3).enumerated()), id: \.element.id) { index, prompt in
                    PromptPill(prompt: prompt, colorIndex: index) {
                        onSelect(prompt)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
