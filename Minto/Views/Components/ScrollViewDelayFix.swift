import SwiftUI
import UIKit

/// Disables `delaysContentTouches` on ancestor UIScrollViews so taps on
/// text fields inside a TabView(.page) are recognized immediately.
struct ScrollViewDelayFix: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            var current: UIView? = view.superview
            while let sv = current {
                if let scrollView = sv as? UIScrollView {
                    scrollView.delaysContentTouches = false
                }
                current = sv.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
