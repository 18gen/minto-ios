import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isResponding: Bool
    var focus: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Follow up...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused(focus)
                .lineLimit(1...5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit(onSend)

            PromptSendButton(size: 32, action: onSend)
                .disabled(!canSend)
                .opacity(canSend ? 1.0 : 0.4)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(AppTheme.inputFill)
    }
}
