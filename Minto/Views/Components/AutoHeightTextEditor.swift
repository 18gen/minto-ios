import SwiftUI

/// A TextEditor that grows to fit its content, enabling it to live inside a ScrollView
/// without its own internal scrolling conflicting with the parent.
struct AutoHeightTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 200

    @State private var textHeight: CGFloat = 200

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 17))
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: max(minHeight, textHeight))
            .background(
                // Hidden Text that measures the actual content height
                Text(text.isEmpty ? " " : text + "\n")
                    .font(.system(size: 17))
                    .padding(.horizontal, 5)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: TextHeightKey.self, value: proxy.size.height)
                    })
                    .hidden()
            )
            .onPreferenceChange(TextHeightKey.self) { height in
                textHeight = height + 32 // padding for cursor and line spacing
            }
    }
}

private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 200
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
