import MarkdownUI
import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage

    @State private var copied = false
    private var isUser: Bool { message.role == .user }

    var body: some View {
        if isUser {
            HStack {
                Spacer(minLength: 60)

                if let recipeLabel = message.recipeLabel {
                    HStack(spacing: 8) {
                        SlashBadge(color: AppTheme.primary)
                        Text(recipeLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceFill)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.surfaceFill)
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
                        .font(.system(size: 15))

                    Button {
                        UIPasteboard.general.string = message.content
                        Haptic.notification(.success)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
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
        }
    }
}

// MARK: - Thinking Indicator

private struct ThinkingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(AppTheme.textSecondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .frame(height: 20)
        .onAppear { animating = true }
    }
}
