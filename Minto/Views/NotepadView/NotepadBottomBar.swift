import SwiftUI

struct NotepadBottomBar: View {
    @Bindable var meeting: Meeting
    @Binding var currentPage: NotePage
    var activeBlockEditorVM: BlockEditorViewModel?
    @Binding var askText: String
    @Binding var isAsking: Bool
    var askFocus: FocusState<Bool>.Binding
    var onDismissKeyboard: (() -> Void)?
    var onOpenChat: ((_ text: String, _ recipeLabel: String?, _ recipeTint: Tint?) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            RecordingStatus()

            if currentPage == .notes, let vm = activeBlockEditorVM, vm.focusedBlockID != nil {
                blockToolbar
            } else {
                floatingBar
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage != .notes {
                activeBlockEditorVM?.hidePicker()
            }
        }
    }

    // MARK: - Block Toolbar (editing mode — block focused)

    private var blockToolbar: some View {
        BlockToolbar(
            mode: toolbarModeBinding,
            isPickerActive: activeBlockEditorVM?.isPickerVisible ?? false,
            onTogglePicker: {
                activeBlockEditorVM?.toggleBlockPicker()
            },
            onDismissEditing: {
                askFocus.wrappedValue = true
                activeBlockEditorVM?.clearFocus(resign: false)
            },
            activeTextView: activeBlockEditorVM?.activeTextView,
            accessory: AnyView(keyboardDismissButton),
            isBoldActive: activeBlockEditorVM?.isBoldActive ?? false,
            isItalicActive: activeBlockEditorVM?.isItalicActive ?? false,
            isUnderlineActive: activeBlockEditorVM?.isUnderlineActive ?? false,
            onFormatChange: { activeBlockEditorVM?.updateFormattingState() }
        )
    }

    private var toolbarModeBinding: Binding<BlockToolbarMode> {
        Binding(
            get: { activeBlockEditorVM?.toolbarMode ?? .main },
            set: { activeBlockEditorVM?.toolbarMode = $0 }
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
            RecordingCapsule(meeting: meeting)
        }
    }
}
