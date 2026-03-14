import SwiftUI

struct NotepadBottomBar: View {
    @Bindable var meeting: Meeting
    @Binding var currentPage: NotePage
    var isNotepadEditing: Bool = false
    var blockEditorVM: BlockEditorViewModel?
    @Binding var askText: String
    @Binding var isAsking: Bool
    var askFocus: FocusState<Bool>.Binding
    var onDismissKeyboard: (() -> Void)?
    var onOpenChat: ((_ text: String, _ recipeLabel: String?, _ recipeTint: Tint?) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            RecordingStatus()

            if currentPage == .notes, let vm = blockEditorVM, vm.focusedBlockID != nil {
                blockToolbar
            } else {
                floatingBar
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage != .notes {
                blockEditorVM?.hidePicker()
            }
        }
    }

    // MARK: - Block Toolbar (editing mode — block focused)

    private var blockToolbar: some View {
        BlockToolbar(
            mode: toolbarModeBinding,
            isPickerActive: blockEditorVM?.isPickerVisible ?? false,
            onTogglePicker: {
                blockEditorVM?.toggleBlockPicker()
            },
            onDismissEditing: {
                askFocus.wrappedValue = true
                blockEditorVM?.clearFocus(resign: false)
            },
            activeTextView: blockEditorVM?.activeTextView,
            accessory: AnyView(keyboardDismissButton),
            isBoldActive: blockEditorVM?.isBoldActive ?? false,
            isItalicActive: blockEditorVM?.isItalicActive ?? false,
            isUnderlineActive: blockEditorVM?.isUnderlineActive ?? false,
            onFormatChange: { blockEditorVM?.updateFormattingState() }
        )
    }

    private var toolbarModeBinding: Binding<BlockToolbarMode> {
        Binding(
            get: { blockEditorVM?.toolbarMode ?? .main },
            set: { blockEditorVM?.toolbarMode = $0 }
        )
    }

    private var keyboardDismissButton: some View {
        CapsuleButton(icon: "keyboard.chevron.compact.down", style: .darkOutline, size: .compact) {
            onDismissKeyboard?()
        }
    }

    // MARK: - Floating Bar (idle / transcript)

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
