import MarkdownUI
import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage

    @State private var copied = false
    private var isUser: Bool { message.role == .user }
    private var recipeColor: Color { message.recipeTint?.color ?? AppTheme.primary }

    var body: some View {
        if isUser {
            HStack {
                Spacer(minLength: 60)

                if let recipeLabel = message.recipeLabel {
                    HStack(spacing: 8) {
                        SlashBadge(color: recipeColor)
                        Text(recipeLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(recipeColor.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.surfaceStroke, lineWidth: 0.8)
                        )
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if message.isLoading {
                    ThinkingIndicator()
                } else {
                    Markdown(message.content)
                        .textSelection(.enabled)
                        .markdownTheme(.chat)

                    Button {
                        UIPasteboard.general.string = message.content
                        Haptic.notification(.success)
                        copied = true
                    } label: {
                        Image(systemName: copied ? "checkmark" : "square.on.square")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .animation(.easeInOut(duration: 0.2), value: copied)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        }
    }
}
