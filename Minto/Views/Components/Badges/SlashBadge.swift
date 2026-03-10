import SwiftUI

struct SlashBadge: View {
    let color: Color

    init(color: Color = AppTheme.primary) {
        self.color = color
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.opacity(0.22))
                .frame(width: 22, height: 22)
            Text("/")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .offset(y: -0.5)
        }
    }
}
