//
//  IconBadge.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI

struct IconBadge: View {
    var body: some View {
        Image(systemName: "doc.text")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .background(Color(.systemGray).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
