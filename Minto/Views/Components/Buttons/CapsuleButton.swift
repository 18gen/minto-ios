import SwiftUI

struct CapsuleButton: View {
    let label: String?
    let icon: String?
    let style: Style
    let size: Size
    let fullWidth: Bool
    let iconWeight: Font.Weight
    let isLoading: Bool
    let action: () -> Void

    enum Style {
        case cream, dark, darkOutline
    }

    enum Size {
        case regular  // .vertical(16), .horizontal(24)
        case compact  // .vertical(12), .horizontal(14)

        var verticalPadding: CGFloat {
            switch self {
            case .regular: 16
            case .compact: 10
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .regular: 24
            case .compact: 16
            }
        }
    }

    init(_ label: String? = nil, icon: String? = nil, style: Style, size: Size = .regular, fullWidth: Bool = false, iconWeight: Font.Weight = .semibold, isLoading: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.style = style
        self.size = size
        self.fullWidth = fullWidth
        self.iconWeight = iconWeight
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            Haptic.impact(.medium)
            action()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
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
                }
            }
            .frame(minWidth: 40, maxWidth: fullWidth ? .infinity : nil)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(Capsule().fill(fillColor))
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: style == .darkOutline ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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
