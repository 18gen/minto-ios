import UIKit

enum BlockAction {
    case splitBlock(id: UUID, cursorPosition: Int)
    case deleteBlock(id: UUID)
    case mergeWithPrevious(id: UUID)
    case focusBlock(id: UUID, cursorPosition: Int?)
    case updateText(id: UUID, text: String)
    case updateAttributedText(id: UUID, attributedText: NSAttributedString)
    case toggleCheck(id: UUID)
    case changeType(id: UUID, newType: BlockType)
}
