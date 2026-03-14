import UIKit

enum BlockType: String, Codable, CaseIterable, Identifiable {
    case text
    case heading1
    case heading2
    case heading3
    case bulletedList
    case numberedList
    case todo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:         L("block.text")
        case .heading1:     L("block.heading1")
        case .heading2:     L("block.heading2")
        case .heading3:     L("block.heading3")
        case .bulletedList: L("block.bulletedList")
        case .numberedList: L("block.numberedList")
        case .todo:         L("block.todo")
        }
    }

    var iconName: String {
        switch self {
        case .text:         "text.alignleft"
        case .heading1:     "h.square"
        case .heading2:     "textformat.size"
        case .heading3:     "textformat.size.smaller"
        case .bulletedList: "list.bullet"
        case .numberedList: "list.number"
        case .todo:         "checkmark.square"
        }
    }

    var font: UIFont {
        switch self {
        case .heading1:     .systemFont(ofSize: 28, weight: .bold)
        case .heading2:     .systemFont(ofSize: 22, weight: .semibold)
        case .heading3:     .systemFont(ofSize: 18, weight: .semibold)
        default:            .systemFont(ofSize: 17)
        }
    }

    /// The type a new block inherits when Enter is pressed.
    var typeForNewBlock: BlockType {
        switch self {
        case .bulletedList, .numberedList, .todo:
            self
        default:
            .text
        }
    }
}

struct Block: Identifiable, Codable, Equatable {
    let id: UUID
    var type: BlockType
    var text: String
    var richTextData: Data?
    var isChecked: Bool

    init(type: BlockType = .text, text: String = "", isChecked: Bool = false) {
        self.id = UUID()
        self.type = type
        self.text = text
        self.richTextData = nil
        self.isChecked = isChecked
    }

    var attributedText: NSAttributedString? {
        guard let data = richTextData else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    mutating func setAttributedText(_ attrStr: NSAttributedString, baseFont: UIFont) {
        text = attrStr.string
        if Self.hasFormatting(attrStr, baseFont: baseFont) {
            richTextData = try? attrStr.data(
                from: NSRange(location: 0, length: attrStr.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        } else {
            richTextData = nil
        }
    }

    private static func hasFormatting(_ attrStr: NSAttributedString, baseFont: UIFont) -> Bool {
        var found = false
        let fullRange = NSRange(location: 0, length: attrStr.length)
        attrStr.enumerateAttributes(in: fullRange) { attrs, _, stop in
            // Check for bold/italic traits
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) || traits.contains(.traitItalic) {
                    found = true
                    stop.pointee = true
                    return
                }
            }
            // Check for underline
            if let underline = attrs[.underlineStyle] as? Int, underline != 0 {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}
