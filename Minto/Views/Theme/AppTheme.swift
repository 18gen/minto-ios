import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.243, green: 0.706, blue: 0.537) // #3EB489 Mint

    static let accent = Color(red: 0.180, green: 0.608, blue: 0.455) // #2E9B74 Mint subtle

    static let background = Color.black

    // recording capsule
    static let creamCTA = Color(red: 0.93, green: 0.90, blue: 0.85)
    static let darkCapsule = Color(white: 0.12)
    static let recordingGreen = Color(red: 0.65, green: 0.80, blue: 0.30)
    static let pausedDots = Color(white: 0.45)

    // surfaces
    static let surfaceFill = Color(white: 0.15)
    static let inputFill = Color(white: 0.15)
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
