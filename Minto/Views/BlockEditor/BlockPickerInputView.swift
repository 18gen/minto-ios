import SwiftUI
import UIKit

final class BlockPickerInputView: UIView {
    private let hostingController: UIHostingController<AnyView>
    private let pickerHeight: CGFloat

    init(height: CGFloat, onSelect: @escaping (BlockType) -> Void) {
        self.pickerHeight = height
        let picker = AnyView(
            BlockPickerGrid(onSelect: onSelect)
                .environment(\.colorScheme, .dark)
        )
        self.hostingController = UIHostingController(rootView: picker)
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height))
        autoresizingMask = [.flexibleWidth]
        backgroundColor = .black

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: pickerHeight)
    }
}
