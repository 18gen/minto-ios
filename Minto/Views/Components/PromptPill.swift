import SwiftUI

struct Prompt: Identifiable {
    let id = UUID()
    let label: String
    let prompt: String
}

// MARK: - Presets

extension Prompt {
    static let home: [Prompt] = [
        .init(label: "List recent todos", prompt: "Please list all action items and todos from these recent meetings"),
        .init(label: "Summarize meetings", prompt: "Please summarize my recent meetings into key points"),
        .init(label: "Write weekly recap", prompt: "Write a weekly recap based on my recent meetings"),
    ]

    static let notepad: [Prompt] = [
        .init(label: "Write follow up email", prompt: "Write a follow up email based on these notes."),
        .init(label: "List my todos", prompt: "List all action items and todos."),
        .init(label: "Make notes longer", prompt: "Rewrite notes to be more detailed and structured."),
    ]
}

// MARK: - Pill

struct PromptPill: View {
    let prompt: Prompt
    var colorIndex: Int = 0
    let action: () -> Void

    private var color: Color {
        let colors = AppTheme.promptColors
        return colors[colorIndex % colors.count]
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                SlashBadge(color: color)
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
