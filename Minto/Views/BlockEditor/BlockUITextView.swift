import SwiftUI
import UIKit

struct BlockUITextView: UIViewRepresentable {
    @Binding var text: String
    let blockType: BlockType
    let isFocused: Bool
    let cursorPosition: Int?
    let richTextData: Data?
    var onReturn: ((Int) -> Void)?
    var onDeleteAtStart: (() -> Void)?
    var onTextChange: ((String) -> Void)?
    var onAttributedTextChange: ((NSAttributedString) -> Void)?
    var onFocusGained: ((BlockTextView) -> Void)?
    var onSelectionChange: (() -> Void)?
    var onMarkdownShortcut: ((BlockType, Bool) -> Void)?

    func makeUIView(context: Context) -> BlockTextView {
        let tv = BlockTextView()
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textColor = .white
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Load initial content
        if let data = richTextData, let attrStr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            tv.attributedText = applyBaseStyle(to: attrStr)
        } else {
            tv.font = blockType.font
            tv.text = text
        }

        tv.onDeleteBackward = { [weak coordinator = context.coordinator] in
            coordinator?.onDeleteAtStart?()
        }

        // Placeholder label
        let placeholder = UILabel()
        placeholder.text = blockType.placeholder
        placeholder.font = blockType.font
        placeholder.textColor = UIColor.white.withAlphaComponent(0.3)
        placeholder.isUserInteractionEnabled = false
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isHidden = true
        tv.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: tv.topAnchor, constant: tv.textContainerInset.top),
            placeholder.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
        ])
        tv.placeholderLabel = placeholder

        return tv
    }

    func updateUIView(_ uiView: BlockTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onReturn = onReturn
        coordinator.onDeleteAtStart = onDeleteAtStart
        coordinator.onTextChange = onTextChange
        coordinator.onAttributedTextChange = onAttributedTextChange
        coordinator.onFocusGained = onFocusGained
        coordinator.onSelectionChange = onSelectionChange
        coordinator.onMarkdownShortcut = onMarkdownShortcut
        coordinator.blockType = blockType

        uiView.onDeleteBackward = { [weak coordinator] in
            coordinator?.onDeleteAtStart?()
        }

        // Update text only if it changed externally (not from typing)
        if !coordinator.isLocalEdit {
            if let data = richTextData, let attrStr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                if uiView.attributedText.string != attrStr.string {
                    uiView.attributedText = applyBaseStyle(to: attrStr)
                }
            } else if uiView.text != text {
                uiView.font = blockType.font
                uiView.text = text
            }
        }
        coordinator.isLocalEdit = false

        // Update font for plain text blocks when type changes
        if richTextData == nil {
            let expectedFont = blockType.font
            if uiView.font != expectedFont {
                uiView.font = expectedFont
            }
        }

        // Placeholder
        uiView.placeholderLabel?.text = blockType.placeholder
        uiView.placeholderLabel?.font = blockType.font
        uiView.placeholderLabel?.isHidden = !(isFocused && text.isEmpty)

        // Focus management
        if isFocused && !uiView.isFirstResponder {
            let setFocus = {
                uiView.becomeFirstResponder()
                if let pos = cursorPosition {
                    let safePos = min(pos, uiView.text.count)
                    if let position = uiView.position(from: uiView.beginningOfDocument, offset: safePos) {
                        uiView.selectedTextRange = uiView.textRange(from: position, to: position)
                    }
                }
            }
            if uiView.window != nil {
                // View already in hierarchy — focus synchronously to prevent keyboard
                // dismiss during rapid block deletions.
                setFocus()
            } else {
                // Newly created view not yet in hierarchy — defer until attached.
                DispatchQueue.main.async { setFocus() }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BlockTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: max(size.height, 28))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Ensure attributed text has white text color and correct base font size.
    private func applyBaseStyle(to attrStr: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attrStr)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: UIColor.white, range: fullRange)
        // Ensure base font size matches block type
        let baseSize = blockType.font.pointSize
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            if font.pointSize != baseSize {
                let descriptor = font.fontDescriptor
                let newFont = UIFont(descriptor: descriptor, size: baseSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
        }
        return mutable
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onReturn: ((Int) -> Void)?
        var onDeleteAtStart: (() -> Void)?
        var onTextChange: ((String) -> Void)?
        var onAttributedTextChange: ((NSAttributedString) -> Void)?
        var onFocusGained: ((BlockTextView) -> Void)?
        var onSelectionChange: (() -> Void)?
        var onMarkdownShortcut: ((BlockType, Bool) -> Void)?
        var blockType: BlockType = .text
        var isLocalEdit = false

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                onReturn?(range.location)
                return false
            }

            // Markdown shortcuts: convert block type when space is typed after a prefix
            if text == " ",
               blockType == .text,
               range.length == 0,
               let currentText = textView.text,
               range.location == currentText.count,
               let (newType, isChecked) = Self.detectMarkdownShortcut(currentText)
            {
                textView.text = ""
                onMarkdownShortcut?(newType, isChecked)
                return false
            }

            return true
        }

        static func detectMarkdownShortcut(_ text: String) -> (BlockType, Bool)? {
            switch text {
            case "-", "*":
                return (.bulletedList, false)
            case "[]", "[ ]":
                return (.todo, false)
            case "[x]", "[X]":
                return (.todo, true)
            case "#":
                return (.heading1, false)
            case "##":
                return (.heading2, false)
            case "###":
                return (.heading3, false)
            default:
                // Numbered list: any digits followed by "."
                if text.count >= 2, text.last == ".",
                   text.dropLast().allSatisfy(\.isWholeNumber)
                {
                    return (.numberedList, false)
                }
                return nil
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            isLocalEdit = true
            let text = textView.text ?? ""
            (textView as? BlockTextView)?.placeholderLabel?.isHidden = !text.isEmpty
            onTextChange?(text)
            onAttributedTextChange?(textView.attributedText)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if let btv = textView as? BlockTextView {
                btv.placeholderLabel?.isHidden = !(textView.text ?? "").isEmpty
                onFocusGained?(btv)
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            (textView as? BlockTextView)?.placeholderLabel?.isHidden = true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            onSelectionChange?()
        }
    }
}
