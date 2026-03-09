import SwiftUI

struct TightLabelStyle: LabelStyle {
    var spacing: CGFloat = 4
    var iconColor: Color = .primary.opacity(0.3)
    var titleColor: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
                .foregroundStyle(iconColor)

            configuration.title
                .foregroundStyle(titleColor)
        }
    }
}

struct MetadataButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .labelStyle(TightLabelStyle(
                spacing: 4,
                iconColor: .primary.opacity(0.3),
                titleColor: .primary.opacity(0.95)
            ))
            .symbolRenderingMode(.hierarchical)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(white: 0.17)))
            .contentShape(Capsule())
    }
}

extension View {
    func metadataButtonStyle() -> some View { modifier(MetadataButtonStyle()) }
}
