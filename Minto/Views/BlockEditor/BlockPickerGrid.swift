import SwiftUI

struct BlockPickerGrid: View {
    let onSelect: (BlockType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("blockPicker.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(BlockType.allCases) { type in
                        BlockTypeCell(type: type) {
                            Haptic.impact(.light)
                            onSelect(type)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
