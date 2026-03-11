import MarkdownUI
import SwiftUI

extension Theme {
    static let chat = Theme()
        .text { FontSize(15) }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle { FontSize(20); FontWeight(.bold) }
                .markdownMargin(top: 12, bottom: 6)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle { FontSize(18); FontWeight(.semibold) }
                .markdownMargin(top: 10, bottom: 4)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle { FontSize(16); FontWeight(.semibold) }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle { FontSize(15); FontWeight(.semibold) }
                .markdownMargin(top: 6, bottom: 2)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle { FontSize(15); FontWeight(.medium) }
                .markdownMargin(top: 4, bottom: 2)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle { FontSize(14); FontWeight(.medium); ForegroundColor(.secondary) }
                .markdownMargin(top: 4, bottom: 2)
        }
}
