import UIKit
import Observation

@Observable @MainActor
final class BlockEditorViewModel {
    var blocks: [Block]
    var focusedBlockID: UUID?
    var cursorPositionAfterFocus: Int?
    var activeTextView: BlockTextView?
    var isPickerVisible = false
    var toolbarMode: BlockToolbarMode = .main
    var isBoldActive = false
    var isItalicActive = false
    var isUnderlineActive = false
    var shouldScrollToFocus = false
    private var pendingBlockRemoval: UUID?

    private weak var meeting: Meeting?
    private var saveTask: Task<Void, Never>?
    private(set) var keyboardHeight: CGFloat = 300

    init(meeting: Meeting) {
        self.meeting = meeting
        if meeting.blocks.isEmpty && !meeting.userNotes.isEmpty {
            self.blocks = [Block(type: .text, text: meeting.userNotes)]
        } else if meeting.blocks.isEmpty {
            self.blocks = [Block(type: .text)]
        } else {
            self.blocks = meeting.blocks
        }
        startObservingKeyboard()
    }

    private func startObservingKeyboard() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            self?.keyboardHeight = frame.height
        }
    }

    // MARK: - Public

    func updateFormattingState() {
        guard let tv = activeTextView else {
            isBoldActive = false; isItalicActive = false; isUnderlineActive = false
            return
        }
        if tv.selectedRange.length == 0 {
            if let font = tv.typingAttributes[.font] as? UIFont {
                isBoldActive = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                isItalicActive = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            } else {
                isBoldActive = false
                isItalicActive = false
            }
            isUnderlineActive = (tv.typingAttributes[.underlineStyle] as? Int ?? 0) != 0
        } else {
            var bold = true, italic = true, underline = true
            tv.attributedText.enumerateAttributes(in: tv.selectedRange, options: []) { attrs, _, _ in
                if let font = attrs[.font] as? UIFont {
                    if !font.fontDescriptor.symbolicTraits.contains(.traitBold) { bold = false }
                    if !font.fontDescriptor.symbolicTraits.contains(.traitItalic) { italic = false }
                } else {
                    bold = false; italic = false
                }
                if (attrs[.underlineStyle] as? Int ?? 0) == 0 { underline = false }
            }
            isBoldActive = bold; isItalicActive = italic; isUnderlineActive = underline
        }
    }

    func clearFocus(resign: Bool = true) {
        guard focusedBlockID != nil else { return }
        let textView = activeTextView
        focusedBlockID = nil
        toolbarMode = .main
        hidePicker()
        if resign {
            DispatchQueue.main.async { [weak textView] in
                textView?.resignFirstResponder()
            }
        }
    }

    /// Called when a block confirms it received first responder (via textViewDidBeginEditing).
    /// If a block deletion is pending, removes it now — safe because the surviving block
    /// already holds first responder, so the keyboard won't dismiss.
    func commitPendingRemoval() {
        guard let id = pendingBlockRemoval else { return }
        pendingBlockRemoval = nil
        DispatchQueue.main.async { [weak self] in
            guard let self, let idx = self.blocks.firstIndex(where: { $0.id == id }) else { return }
            self.blocks.remove(at: idx)
            self.debouncedSave()
        }
    }

    func handleAction(_ action: BlockAction) {
        switch action {
        case let .splitBlock(id, cursorPosition):
            splitBlock(id: id, at: cursorPosition)
        case let .deleteBlock(id):
            deleteBlock(id: id)
        case let .mergeWithPrevious(id):
            mergeWithPrevious(id: id)
        case let .focusBlock(id, cursorPosition):
            focusedBlockID = id
            cursorPositionAfterFocus = cursorPosition
        case let .updateText(id, text):
            updateText(id: id, text: text)
        case let .updateAttributedText(id, attributedText):
            updateAttributedText(id: id, attrText: attributedText)
        case let .toggleCheck(id):
            toggleCheck(id: id)
        case let .changeType(id, newType):
            changeType(id: id, to: newType)
        }
    }

    func save() {
        meeting?.blocks = blocks
        meeting?.userNotes = blocks.map(\.text).joined(separator: "\n")
    }

    func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func listIndex(for blockIndex: Int) -> Int {
        guard blockIndex < blocks.count, blocks[blockIndex].type == .numberedList else { return 1 }
        var count = 1
        var i = blockIndex - 1
        while i >= 0 && blocks[i].type == .numberedList {
            count += 1
            i -= 1
        }
        return count
    }

    // MARK: - Block Picker

    func toggleBlockPicker() {
        if isPickerVisible {
            hidePicker()
        } else {
            if activeTextView == nil {
                focusedBlockID = blocks.last?.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.showPicker()
                }
            } else {
                showPicker()
            }
        }
    }

    func insertBlockFromPicker(type: BlockType) {
        let insertIndex: Int
        if let id = focusedBlockID, let idx = blocks.firstIndex(where: { $0.id == id }) {
            insertIndex = idx + 1
        } else {
            insertIndex = blocks.count
        }

        // Clear inputView before focus change — let first responder transfer handle animation
        activeTextView?.inputView = nil

        let newBlock = Block(type: type)
        blocks.insert(newBlock, at: insertIndex)
        isPickerVisible = false
        focusedBlockID = newBlock.id
        cursorPositionAfterFocus = 0
        debouncedSave()
    }

    func hidePicker() {
        guard isPickerVisible else { return }
        isPickerVisible = false
        activeTextView?.setBlockPickerInput(nil)
    }

    private func showPicker() {
        let pickerView = BlockPickerInputView(height: keyboardHeight) { [weak self] type in
            self?.insertBlockFromPicker(type: type)
        }
        isPickerVisible = true
        activeTextView?.setBlockPickerInput(pickerView)
    }

    // MARK: - Private

    private func splitBlock(id: UUID, at cursorPosition: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let block = blocks[index]
        let text = block.text

        let splitIndex = text.index(text.startIndex, offsetBy: min(cursorPosition, text.count))
        let before = String(text[text.startIndex..<splitIndex])
        let after = String(text[splitIndex..<text.endIndex])

        blocks[index].text = before
        blocks[index].richTextData = nil // Simplify: clear formatting on split

        let newType = block.type.typeForNewBlock
        let newBlock = Block(type: newType, text: after)
        blocks.insert(newBlock, at: index + 1)

        shouldScrollToFocus = true
        focusedBlockID = newBlock.id
        cursorPositionAfterFocus = 0
        debouncedSave()
    }

    private func deleteBlock(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), blocks.count > 1 else { return }

        // Phase 1: Focus the surviving block (no removal yet).
        // SwiftUI renders → surviving block's updateUIView → becomeFirstResponder().
        let focusIndex = index > 0 ? index - 1 : 1
        shouldScrollToFocus = true
        pendingBlockRemoval = id
        focusedBlockID = blocks[focusIndex].id
        cursorPositionAfterFocus = blocks[focusIndex].text.count

        // Phase 2 happens in commitPendingRemoval(), triggered by onFocusGained
        // when the surviving block confirms it received first responder.
        // Fallback: if focus transfer doesn't fire within 200ms, remove anyway.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.commitPendingRemoval()
        }
    }

    private func mergeWithPrevious(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), index > 0 else { return }

        let currentText = blocks[index].text
        let prevLength = blocks[index - 1].text.count

        blocks[index - 1].text += currentText
        blocks[index - 1].richTextData = nil // Clear formatting on merge
        blocks[index].text = "" // Clear so it's not visible during delayed removal

        shouldScrollToFocus = true
        pendingBlockRemoval = id
        focusedBlockID = blocks[index - 1].id
        cursorPositionAfterFocus = prevLength

        // Fallback if onFocusGained doesn't fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.commitPendingRemoval()
        }
    }

    private func updateText(id: UUID, text: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].text = text
        debouncedSave()
    }

    private func updateAttributedText(id: UUID, attrText: NSAttributedString) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].setAttributedText(attrText, baseFont: blocks[index].type.font)
        debouncedSave()
    }

    private func toggleCheck(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].isChecked.toggle()
        debouncedSave()
    }

    private func changeType(id: UUID, to newType: BlockType) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].type = newType
        debouncedSave()
    }
}
