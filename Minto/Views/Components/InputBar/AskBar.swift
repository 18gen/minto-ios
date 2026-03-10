import SwiftUI

struct AskBar<Accessory: View>: View {
    @Binding var text: String
    @Binding var isAsking: Bool
    var focus: FocusState<Bool>.Binding
    var placeholder: String
    let onSend: () -> Void
    var accessory: Accessory

    @State private var isExpanded = false

    init(
        text: Binding<String>,
        isAsking: Binding<Bool>,
        focus: FocusState<Bool>.Binding,
        placeholder: String = "Ask anything",
        onSend: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self._text = text
        self._isAsking = isAsking
        self.focus = focus
        self.placeholder = placeholder
        self.onSend = onSend
        self.accessory = accessory()
    }

    private var shouldShowSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var lineCount: Int {
        text.components(separatedBy: "\n").count
    }

    private var shouldShowExpand: Bool {
        lineCount > 3
    }

    private var isMultiLine: Bool {
        lineCount > 1
    }

    var body: some View {
        HStack(alignment: isMultiLine ? .bottom : .center, spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused(focus)
                .lineLimit(isExpanded ? 1 ... 12 : 1 ... 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, shouldShowSend ? 30 : 0)
                .onSubmit(onSend)

            accessory
        }
        .frame(minHeight: 32)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, isMultiLine ? 10 : 5)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.inputFill))
        .overlay(alignment: .bottomTrailing) {
            if shouldShowSend {
                PromptSendButton(size: 32, action: onSend)
                    .disabled(isAsking)
                    .padding(.trailing, 5)
                    .padding(.bottom, 5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if shouldShowExpand {
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.80)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "arrow.up.right.and.arrow.down.left" : "arrow.down.left.and.arrow.up.right")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.surfaceStroke, lineWidth: 1)
                .blendMode(.overlay)
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.80), value: shouldShowSend)
    }
}

extension AskBar where Accessory == EmptyView {
    init(
        text: Binding<String>,
        isAsking: Binding<Bool>,
        focus: FocusState<Bool>.Binding,
        placeholder: String = "Ask anything",
        onSend: @escaping () -> Void
    ) {
        self._text = text
        self._isAsking = isAsking
        self.focus = focus
        self.placeholder = placeholder
        self.onSend = onSend
        self.accessory = EmptyView()
    }
}
