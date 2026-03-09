import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isProminent ? AppTheme.primary.opacity(0.18) : Color.primary.opacity(0.06))
            }
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SlashBadge: View {
    let color: Color

    init(color: Color = AppTheme.primary) {
        self.color = color
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.opacity(0.22))
                .frame(width: 22, height: 22)
            Text("/")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .offset(y: -0.5)
        }
    }
}
