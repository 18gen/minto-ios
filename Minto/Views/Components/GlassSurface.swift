import SwiftUI

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var stroke: CGFloat = 1
    var padding: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                #if os(macOS)
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                #else
                    Color(.systemBackground).opacity(0.85)
                #endif
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.surfaceStroke, lineWidth: stroke)
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.20), radius: 26, y: 12)
            .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat, stroke: CGFloat = 1, padding: CGFloat = 10) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, stroke: stroke, padding: padding))
    }
}
