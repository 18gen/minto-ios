import SwiftUI

enum AppTheme {
    static let primary = Color.accentColor

    static let accent = Color(red: 0.40, green: 0.55, blue: 0.68)

    static let background = Color.black

    // surfaces
    static let surfaceFill = Color.primary.opacity(0.06)
    static let inputFill = Color(white: 0.17)
    static let surfaceStroke = Color.white.opacity(0.10)
    static let surfaceStrokeStrong = Color.white.opacity(0.16)

    // text
    static let textPrimary: Color = .primary
    static let textSecondary: Color = .secondary
    static let textTertiary: Color = .primary.opacity(0.45)

    // sizing
    static let barCorner: CGFloat = 26
    static let pillCorner: CGFloat = 999
}
