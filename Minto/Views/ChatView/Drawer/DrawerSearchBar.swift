import SwiftUI

struct DrawerSearchBar: View {
    @Binding var searchText: String
    var searchFocused: FocusState<Bool>.Binding
    var isSearching: Bool
    let onNewChat: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search", text: $searchText)
                    .font(.system(size: 17))
                    .focused(searchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .glassEffect(.regular, in: .capsule)

            if isSearching {
                Button {
                    searchText = ""
                    searchFocused.wrappedValue = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .transition(.scale.combined(with: .opacity))
            } else {
                Button {
                    Haptic.impact(.light)
                    onNewChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearching)
    }
}
