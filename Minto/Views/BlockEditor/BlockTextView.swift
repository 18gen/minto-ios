import UIKit

final class BlockTextView: UITextView {
    var onDeleteBackward: (() -> Void)?
    var placeholderLabel: UILabel?

    override func deleteBackward() {
        if selectedRange.location == 0 && selectedRange.length == 0 {
            onDeleteBackward?()
            return
        }
        super.deleteBackward()
    }

    // MARK: - Input View

    func setBlockPickerInput(_ view: UIView?) {
        inputView = view
        reloadInputViews()
    }

    // MARK: - Inline Formatting

    func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        let nsRange = selectedRange

        if nsRange.length > 0 {
            let mutable = NSMutableAttributedString(attributedString: attributedText)
            mutable.enumerateAttribute(.font, in: nsRange, options: []) { value, range, _ in
                guard let font = value as? UIFont else { return }
                let hasTrait = font.fontDescriptor.symbolicTraits.contains(trait)
                let newTraits = hasTrait
                    ? font.fontDescriptor.symbolicTraits.subtracting(trait)
                    : font.fontDescriptor.symbolicTraits.union(trait)
                guard let descriptor = font.fontDescriptor.withSymbolicTraits(newTraits) else { return }
                let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            attributedText = mutable
            // Restore selection
            selectedRange = nsRange
        } else {
            var attrs = typingAttributes
            if let font = attrs[.font] as? UIFont {
                let hasTrait = font.fontDescriptor.symbolicTraits.contains(trait)
                let newTraits = hasTrait
                    ? font.fontDescriptor.symbolicTraits.subtracting(trait)
                    : font.fontDescriptor.symbolicTraits.union(trait)
                if let descriptor = font.fontDescriptor.withSymbolicTraits(newTraits) {
                    attrs[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
                }
            }
            typingAttributes = attrs
        }
    }

    func toggleUnderline() {
        let nsRange = selectedRange

        if nsRange.length > 0 {
            let mutable = NSMutableAttributedString(attributedString: attributedText)
            let hasUnderline = (mutable.attribute(.underlineStyle, at: nsRange.location, effectiveRange: nil) as? Int ?? 0) != 0
            if hasUnderline {
                mutable.removeAttribute(.underlineStyle, range: nsRange)
            } else {
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            }
            attributedText = mutable
            selectedRange = nsRange
        } else {
            var attrs = typingAttributes
            let has = (attrs[.underlineStyle] as? Int ?? 0) != 0
            attrs[.underlineStyle] = has ? 0 : NSUnderlineStyle.single.rawValue
            typingAttributes = attrs
        }
    }
}
