import SwiftUI

struct PromptsTray: View {
    let prompts: [Prompt]
    let onSelect: (Prompt) -> Void
    var showGridButton: Bool = false
    var isExpanded: Binding<Bool>?

    private var expanded: Bool {
        isExpanded?.wrappedValue ?? false
    }

    var body: some View {
        if expanded {
            expandedView
        } else {
            collapsedView
        }
    }

    // MARK: - Collapsed (horizontal pills)

    private var collapsedView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if showGridButton {
                    Button {
                        Haptic.impact(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded?.wrappedValue = true
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surfaceFill)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(Array(prompts.prefix(3).enumerated()), id: \.element.id) { index, prompt in
                    PromptPill(prompt: prompt, colorIndex: index) {
                        onSelect(prompt)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Expanded (vertical list)

    private var expandedView: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Recipes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Haptic.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded?.wrappedValue = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.surfaceFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Recipe buttons
            VStack(spacing: 2) {
                ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                    Button {
                        Haptic.impact(.light)
                        onSelect(prompt)
                    } label: {
                        HStack(spacing: 10) {
                            SlashBadge(color: AppTheme.promptColors[index % AppTheme.promptColors.count])
                            Text(prompt.label)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RecipeRowButtonStyle())
                }
            }
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.surfaceStroke, lineWidth: 1)
        )
        .transition(.scale(scale: 0.95, anchor: .bottom).combined(with: .opacity))
    }
}

// MARK: - Recipe Row Button Style

private struct RecipeRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? Color.white.opacity(0.08) : .clear)
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
