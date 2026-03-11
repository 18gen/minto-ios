import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.243, green: 0.706, blue: 0.537) // #3EB489 Mint

    static let accent = Color(red: 0.180, green: 0.608, blue: 0.455) // #2E9B74 Mint subtle

    static let background = Color.black

    // recording capsule
    static let ctaFill = Color(red: 0.93, green: 0.90, blue: 0.85)
    static let surfaceElevated = Color(white: 0.12)

    // speaker diarization
    static let speakerColors: [Color] = [
        Color(red: 0.45, green: 0.65, blue: 0.50), // sage
        Color(red: 0.65, green: 0.45, blue: 0.70), // purple
        Color(red: 0.70, green: 0.55, blue: 0.40), // warm orange
        Color(red: 0.40, green: 0.55, blue: 0.75), // steel blue
        Color(red: 0.75, green: 0.45, blue: 0.50), // rose
        Color(red: 0.55, green: 0.65, blue: 0.40), // olive
        Color(red: 0.65, green: 0.50, blue: 0.60), // mauve
        Color(red: 0.50, green: 0.60, blue: 0.65), // slate teal
    ]
    static let userSpeakerColor: Color = accent

    // surfaces
    static let surface = Color(white: 0.15)
    static let surfaceStroke = Color.white.opacity(0.10)

    // text
    static let textPrimary: Color = .primary
    static let textSecondary: Color = .secondary
    static let textTertiary: Color = .primary.opacity(0.45)
}

extension Tint {
    var color: Color {
        switch self {
        case .mint:  return AppTheme.primary
        case .green: return Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
        case .cyan:  return Color(red: 0.196, green: 0.678, blue: 0.902) // #32ADE6
        }
    }
}
