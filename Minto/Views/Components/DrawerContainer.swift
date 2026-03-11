import SwiftUI

/// Reusable left-side drawer container with offset animation, scrim overlay,
/// tap-to-dismiss, and drag gesture.
struct DrawerContainer<Drawer: View, Content: View>: View {
    @Binding var isOpen: Bool
    var isExpanded: Binding<Bool>?
    @ViewBuilder let drawer: () -> Drawer
    @ViewBuilder let content: () -> Content

    private let normalWidth: CGFloat = 280

    var body: some View {
        GeometryReader { geo in
            let expanded = isExpanded?.wrappedValue ?? false
            let effectiveWidth = expanded ? geo.size.width : normalWidth

            ZStack(alignment: .leading) {
                content()
                    .offset(x: isOpen ? effectiveWidth : 0)
                    .overlay {
                        if isOpen, !expanded {
                            Color.white.opacity(0.15)
                                .ignoresSafeArea()
                                .onTapGesture { isOpen = false }
                        }
                    }

                if isOpen {
                    drawer()
                        .frame(width: effectiveWidth)
                        .transition(.move(edge: .leading))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(AppTheme.Anim.spring, value: isOpen)
        .animation(AppTheme.Anim.spring, value: isExpanded?.wrappedValue)
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width > 80, !isOpen {
                    isOpen = true
                } else if value.translation.width < -80, isOpen {
                    isOpen = false
                }
            }
    }
}
