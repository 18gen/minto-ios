import SwiftUI

extension AppTheme {
    enum Anim {
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let springSnappy = SwiftUI.Animation.spring(response: 0.22, dampingFraction: 0.8)
    }
}
