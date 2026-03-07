//
//  Pill.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-25.
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isProminent ? AppTheme.primary.opacity(0.18) : Color.primary.opacity(0.06))
            }
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SlashBadge: View {
    enum Style {
        case blue
        case green
        case cyan
        case gray

        var fill: Color {
            switch self {
            case .blue: return AppTheme.primary.opacity(0.22)
            case .green: return Color.green.opacity(0.22)
            case .cyan: return Color.cyan.opacity(0.22)
            case .gray: return Color.primary.opacity(0.10)
            }
        }

        var slash: Color {
            switch self {
            case .blue: return AppTheme.primary
            case .green: return .green
            case .cyan: return .cyan
            case .gray: return .secondary
            }
        }
    }

    var style: Style = .blue

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(style.fill)
                .frame(width: 22, height: 22)
            Text("/")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style.slash)
                .offset(y: -0.5)
        }
    }
}
