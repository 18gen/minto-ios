import SwiftUI

struct BlockRowView: View {
    @Binding var block: Block
    let isFocused: Bool
    let cursorPosition: Int?
    let listIndex: Int
    var onAction: (BlockAction) -> Void
    var onFocusGained: ((BlockTextView) -> Void)?
    var onSelectionChange: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            leadingDecoration
            BlockUITextView(
                text: $block.text,
                blockType: block.type,
                isFocused: isFocused,
                cursorPosition: cursorPosition,
                richTextData: block.richTextData,
                onReturn: { pos in onAction(.splitBlock(id: block.id, cursorPosition: pos)) },
                onDeleteAtStart: {
                    if block.text.isEmpty {
                        if block.type != .text {
                            onAction(.changeType(id: block.id, newType: .text))
                        } else {
                            onAction(.deleteBlock(id: block.id))
                        }
                    } else {
                        onAction(.mergeWithPrevious(id: block.id))
                    }
                },
                onTextChange: { text in onAction(.updateText(id: block.id, text: text)) },
                onAttributedTextChange: { attrText in onAction(.updateAttributedText(id: block.id, attributedText: attrText)) },
                onFocusGained: { textView in
                    onAction(.focusBlock(id: block.id, cursorPosition: nil))
                    onFocusGained?(textView)
                },
                onSelectionChange: onSelectionChange,
                onMarkdownShortcut: { newType, isChecked in
                    onAction(.applyMarkdownShortcut(id: block.id, newType: newType, isChecked: isChecked))
                }
            )
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, 16)
        .padding(.top, topPadding)
        .padding(.bottom, 2)
    }

    // MARK: - Leading Decoration

    @ViewBuilder
    private var leadingDecoration: some View {
        switch block.type {
        case .bulletedList:
            Circle()
                .fill(Color.primary)
                .frame(width: 6, height: 6)
                .padding(.top, 13)

        case .numberedList:
            Text("\(listIndex).")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .frame(minWidth: 20, alignment: .trailing)

        case .todo:
            Button {
                onAction(.toggleCheck(id: block.id))
            } label: {
                Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(block.isChecked ? AppTheme.primary : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

        default:
            EmptyView()
        }
    }

    // MARK: - Padding

    private var leadingPadding: CGFloat {
        switch block.type {
        case .bulletedList, .numberedList, .todo: 28
        default: 16
        }
    }

    private var topPadding: CGFloat {
        switch block.type {
        case .heading1: 12
        case .heading2: 8
        case .heading3: 6
        default: 2
        }
    }
}
