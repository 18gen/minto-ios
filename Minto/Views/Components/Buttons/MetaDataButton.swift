//
//  MetaDataButton.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI

struct TightLabelStyle: LabelStyle {
    var spacing: CGFloat = 4
    var iconColor: Color = .primary.opacity(0.3)
    var titleColor: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
                .foregroundStyle(iconColor)

            configuration.title
                .foregroundStyle(titleColor)
        }
    }
}

struct MetadataButtonStyle: ViewModifier {
    @State private var isHovering = false

    private var outline: Color { .primary.opacity(0.3) }

    func body(content: Content) -> some View {
        content
            .font(.body)
            .labelStyle(TightLabelStyle(
                spacing: 4,
                iconColor: outline,
                titleColor: .primary.opacity(0.95)
            ))
            .symbolRenderingMode(.hierarchical)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.secondary.opacity(0.12) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(outline, lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            #if os(macOS)
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.12)) { isHovering = hover }
            }
            #endif
    }
}

extension View {
    func metadataButtonStyle() -> some View { modifier(MetadataButtonStyle()) }
}
