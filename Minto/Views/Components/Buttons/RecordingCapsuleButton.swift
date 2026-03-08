import SwiftUI

struct RecordingCapsuleButton: View {
    let label: String?
    let icon: String?
    let style: Style
    let fullWidth: Bool
    let iconWeight: Font.Weight
    let action: () -> Void

    enum Style {
        case cream, dark, darkOutline
    }

    init(_ label: String? = nil, icon: String? = nil, style: Style, fullWidth: Bool = false, iconWeight: Font.Weight = .semibold, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.style = style
        self.fullWidth = fullWidth
        self.iconWeight = iconWeight
        self.action = action
    }

    var body: some View {
        Button {
            Haptic.impact(.medium)
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: iconWeight))
                }
                if let label {
                    Text(label)
                        .font(.system(size: 16))
                }
            }
            .frame(minWidth: 40, maxWidth: fullWidth ? .infinity : nil)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Capsule().fill(fillColor))
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: style == .darkOutline ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .cream: .black
        case .dark, .darkOutline: .white
        }
    }

    private var fillColor: Color {
        switch style {
        case .cream: AppTheme.creamCTA
        case .dark, .darkOutline: AppTheme.darkCapsule
        }
    }

    private var borderColor: Color {
        switch style {
        case .darkOutline: .white.opacity(0.25)
        default: .clear
        }
    }
}
