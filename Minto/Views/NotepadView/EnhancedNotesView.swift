import SwiftUI

struct EnhancedNotesView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17))
            .foregroundStyle(AppTheme.textSecondary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }
}
