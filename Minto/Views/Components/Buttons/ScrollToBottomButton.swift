import SwiftUI

struct ScrollToBottomButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        if isVisible {
            Button {
                Haptic.impact(.light)
                action()
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.surfaceFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 70)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
