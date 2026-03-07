import SwiftUI

struct RecordingCapsuleButton: View {
    let label: String?
    let icon: String?
    let style: Style
    let action: () -> Void

    enum Style {
        case cream, dark, darkOutline
    }

    init(_ label: String? = nil, icon: String? = nil, style: Style, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                if let label {
                    Text(label)
                        .font(.system(size: 16))
                }
            }
            .frame(minWidth: 40)
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
        case .cream: return .black
        case .dark, .darkOutline: return .white
        }
    }

    private var fillColor: Color {
        switch style {
        case .cream: return AppTheme.creamCTA
        case .dark, .darkOutline: return AppTheme.darkCapsule
        }
    }

    private var borderColor: Color {
        switch style {
        case .darkOutline: return .white.opacity(0.25)
        default: return .clear
        }
    }
}
