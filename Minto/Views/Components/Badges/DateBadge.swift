import SwiftUI

struct DateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: -1) {
            Text(monthAbbreviation)
                .font(.system(size: 6, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(AppTheme.accent.opacity(0.95))
                .textCase(.uppercase)
                .padding(.top, 1)

            Text(dayNumber)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.96))
                .offset(y: -0.5) // optical centering
        }
        .frame(width: 30, height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX") // stable "FEB"
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
