import SwiftUI

/// Reusable left-side drawer container with offset animation, scrim overlay,
/// tap-to-dismiss, and drag gesture.
struct DrawerContainer<Drawer: View, Content: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let drawer: () -> Drawer
    @ViewBuilder let content: () -> Content

    private let drawerWidth: CGFloat = 280

    var body: some View {
        ZStack(alignment: .leading) {
            content()
                .offset(x: isOpen ? drawerWidth : 0)
                .overlay {
                    if isOpen {
                        Color.white.opacity(0.15)
                            .ignoresSafeArea()
                            .onTapGesture { isOpen = false }
                    }
                }

            if isOpen {
                drawer()
                    .frame(width: drawerWidth)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isOpen)
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
