//
//  ReceiptPill.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-25.
//

import SwiftUI

struct Receipt: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prompt: String
    let style: SlashBadge.Style
}

struct ReceiptPill: View {
    let receipt: Receipt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SlashBadge(style: receipt.style)
                Text(receipt.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .buttonStyle(PillButtonStyle())
    }
}

struct AllRecipesMenu: SwiftUI.View {
    let receipts: [Receipt]
    let onPick: (Receipt) -> Void

    var body: some SwiftUI.View {
        SwiftUI.Menu {
            SwiftUI.ForEach(receipts) { r in
                SwiftUI.Button {
                    onPick(r)
                } label: {
                    SwiftUI.Text(r.title)
                }
            }
        } label: {
            SwiftUI.HStack(spacing: 8) {
                SwiftUI.Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                SwiftUI.Text("All recipes")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(AppTheme.textPrimary)
        }
        .buttonStyle(PillButtonStyle())
    }
}
