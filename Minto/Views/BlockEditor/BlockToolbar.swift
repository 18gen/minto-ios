import SwiftUI

enum BlockToolbarMode: Equatable {
    case main
    case format
}

struct BlockToolbar: View {
    @Binding var mode: BlockToolbarMode

    // Block picker (via inputView)
    let isPickerActive: Bool
    let onTogglePicker: () -> Void

    // Dismiss editing (sparkles button — clears focus, shows FloatingBar)
    let onDismissEditing: () -> Void

    // Format
    let activeTextView: BlockTextView?

    // Right accessory (keyboard dismiss button)
    let accessory: AnyView?

    // Formatting state
    var isBoldActive: Bool = false
    var isItalicActive: Bool = false
    var isUnderlineActive: Bool = false
    var onFormatChange: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, AppTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            .allowsHitTesting(false)

            toolbarBar
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .background(AppTheme.background)
        .animation(AppTheme.Anim.spring, value: mode)
    }

    // MARK: - Toolbar Bar

    private var toolbarBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                if mode == .format {
                    formatBarContent
                } else {
                    mainBarContent
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(AppTheme.surfaceElevated)
                    .overlay(Capsule().stroke(AppTheme.surfaceStroke, lineWidth: 1))
            )

            Spacer()

            if let accessory {
                accessory
            }
        }
    }

    // MARK: - Main Bar: [AI] [+] [Aa]

    private var mainBarContent: some View {
        HStack(spacing: 12) {
            // AI button — dismisses editing, returns to FloatingBar
            toolbarIcon("sparkles") {
                onDismissEditing()
            }
            .foregroundStyle(.primary)

            // "+" toggle — swaps keyboard with block picker via inputView
            toolbarIcon("plus") {
                Haptic.impact(.light)
                onTogglePicker()
            }
            .foregroundStyle(isPickerActive ? AppTheme.primary : .primary)

            // "Aa"
            Button {
                withAnimation(AppTheme.Anim.spring) {
                    mode = .format
                }
            } label: {
                Text("Aa")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Format Bar: [<<] [B] [I] [U]

    private var formatBarContent: some View {
        HStack(spacing: 12) {
            toolbarIcon("chevron.backward.2") {
                withAnimation(AppTheme.Anim.spring) {
                    mode = .main
                }
            }
            .foregroundStyle(.secondary)

            Divider()
                .frame(height: 20)
                .background(AppTheme.surfaceStroke)

            formatTextButton("B", weight: .bold, isActive: isBoldActive) {
                activeTextView?.toggleTrait(.traitBold)
                onFormatChange?()
            }

            formatTextButton("I", italic: true, isActive: isItalicActive) {
                activeTextView?.toggleTrait(.traitItalic)
                onFormatChange?()
            }

            formatTextButton("U", underlined: true, isActive: isUnderlineActive) {
                activeTextView?.toggleUnderline()
                onFormatChange?()
            }
        }
    }

    // MARK: - Helpers

    private func toolbarIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 28, height: 28)
        }
    }

    private func formatTextButton(
        _ label: String,
        weight: Font.Weight = .regular,
        italic: Bool = false,
        underlined: Bool = false,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptic.impact(.light)
            action()
        } label: {
            Text(label)
                .font(.system(size: 18, weight: weight))
                .italic(italic)
                .underline(underlined)
                .frame(width: 28, height: 28)
                .foregroundStyle(isActive ? AppTheme.primary : .primary)
        }
    }
}
