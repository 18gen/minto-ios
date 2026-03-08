import SwiftUI

struct IconBadge: View {
    var icon: String = "doc.text"
    var tint: Color = .secondary

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
            )
    }
}
