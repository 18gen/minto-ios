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

    var placeholder: String {
        switch self {
        case .text: L("placeholder.typeHere")
        default: displayName
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

    /// Parses markdown-like plain text into an array of blocks.
    static func parseFromText(_ text: String) -> [Block] {
        var blocks: [Block] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("### ") {
                blocks.append(Block(type: .heading3, text: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(Block(type: .heading2, text: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(Block(type: .heading1, text: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                blocks.append(Block(type: .todo, text: String(trimmed.dropFirst(6)), isChecked: true))
            } else if trimmed.hasPrefix("- [ ] ") {
                blocks.append(Block(type: .todo, text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix("- ") {
                blocks.append(Block(type: .bulletedList, text: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("* ") {
                blocks.append(Block(type: .bulletedList, text: String(trimmed.dropFirst(2))))
            } else if let dotIndex = trimmed.firstIndex(of: "."),
                      trimmed[trimmed.startIndex..<dotIndex].allSatisfy(\.isWholeNumber),
                      trimmed.index(after: dotIndex) < trimmed.endIndex,
                      trimmed[trimmed.index(after: dotIndex)] == " "
            {
                let content = String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...])
                blocks.append(Block(type: .numberedList, text: content))
            } else {
                blocks.append(Block(type: .text, text: trimmed))
            }
        }
        return blocks.isEmpty ? [Block(type: .text)] : blocks
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
