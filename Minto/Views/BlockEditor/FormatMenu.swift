import SwiftUI

struct FormatMenu: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            formatButton(label: "B", weight: .bold) { onBold() }
            formatButton(label: "I", weight: .regular, italic: true) { onItalic() }
            formatButton(label: "U", weight: .regular, underlined: true) { onUnderline() }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func formatButton(
        label: String,
        weight: Font.Weight = .regular,
        italic: Bool = false,
        underlined: Bool = false,
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
                .foregroundStyle(.primary)
                .frame(width: 44, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
    }
}
