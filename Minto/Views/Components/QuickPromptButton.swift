import SwiftUI

struct QuickPrompt: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let prompt: String
}

struct QuickPromptButton: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: prompt.icon)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                    .padding(5)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(prompt.label)
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Pill-outlined variant for the collapsed inline prompt
struct QuickPromptPill: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: prompt.icon)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.accent)
                    .padding(4)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(prompt.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppTheme.surfaceFill))
            .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
