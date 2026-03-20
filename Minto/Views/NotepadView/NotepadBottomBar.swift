import SwiftUI

struct NotepadBottomBar: View {
    @Bindable var meeting: Meeting
    @Binding var currentPage: NotePage
    var isNotepadEditing: Bool = false
    @Binding var askText: String
    @Binding var isAsking: Bool
    var askFocus: FocusState<Bool>.Binding
    var onDismissKeyboard: (() -> Void)?
    var onOpenChat: ((_ text: String, _ recipeLabel: String?, _ recipeTint: Tint?) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            RecordingStatus()
            floatingBar
        }
    }

    // MARK: - Floating Bar

    private var floatingBar: some View {
        FloatingBar(
            prompts: Prompt.notepad(for: AppSettings.shared.language),
            askText: $askText,
            isAsking: $isAsking,
            askFocus: askFocus,
            onSend: {
                let text = askText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                askText = ""
                askFocus.wrappedValue = false
                onOpenChat?(text, nil, nil)
            },
            onPromptSelect: { p in
                askFocus.wrappedValue = false
                onOpenChat?(p.prompt, p.label, p.tint)
            }
        ) {
            if isNotepadEditing, let onDismissKeyboard {
                CapsuleButton(icon: "keyboard.chevron.compact.down", style: .darkOutline, size: .compact) {
                    onDismissKeyboard()
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                RecordingCapsule(meeting: meeting)
            }
        }
    }
}
