import SwiftUI

struct SlashBadge: View {
    let color: Color

    init(color: Color = AppTheme.primary) {
        self.color = color
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
            Text("/")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(white: 0.15))
                .offset(y: -0.5)
        }
    }
}
