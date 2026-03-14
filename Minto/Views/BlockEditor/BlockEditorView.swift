import SwiftUI

struct BlockEditorView: View {
    @Bindable var viewModel: BlockEditorViewModel

    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.blocks.enumerated()), id: \.element.id) { index, block in
                    BlockRowView(
                        block: blockBinding(for: block.id),
                        isFocused: viewModel.focusedBlockID == block.id,
                        cursorPosition: viewModel.focusedBlockID == block.id ? viewModel.cursorPositionAfterFocus : nil,
                        listIndex: viewModel.listIndex(for: index),
                        onAction: viewModel.handleAction,
                        onFocusGained: { textView in
                            viewModel.activeTextView = textView
                            viewModel.commitPendingRemoval()
                        },
                        onSelectionChange: {
                            viewModel.updateFormattingState()
                        }
                    )
                    .id(block.id)
                }
            }
            .onChange(of: viewModel.focusedBlockID) { _, newID in
                if let id = newID, viewModel.shouldScrollToFocus {
                    viewModel.shouldScrollToFocus = false
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onDisappear {
                viewModel.save()
            }
        }
    }

    private func blockBinding(for id: UUID) -> Binding<Block> {
        Binding(
            get: {
                guard let idx = viewModel.blocks.firstIndex(where: { $0.id == id }) else {
                    return Block()
                }
                return viewModel.blocks[idx]
            },
            set: { newValue in
                if let idx = viewModel.blocks.firstIndex(where: { $0.id == id }) {
                    viewModel.blocks[idx] = newValue
                }
            }
        )
    }
}
