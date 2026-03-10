import SwiftUI

struct TranscriptBubble: View {
    let text: String
    let isPartial: Bool
    var isUserSpeaker: Bool = false
    var speakerColor: Color?

    private var alignRight: Bool { isUserSpeaker }

    private var bubbleColor: Color {
        if isPartial { return Color.secondary.opacity(0.06) }
        if isUserSpeaker { return AppTheme.userSpeakerColor.opacity(0.12) }
        if let speakerColor { return speakerColor.opacity(0.10) }
        return AppTheme.accent.opacity(0.10)
    }

    private var leadingAccent: Color? {
        if isPartial || isUserSpeaker { return nil }
        return speakerColor
    }

    var body: some View {
        HStack {
            if alignRight { Spacer(minLength: 40) }
            HStack(spacing: 0) {
                if let accent = leadingAccent {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accent)
                        .frame(width: 3)
                        .padding(.vertical, 4)
                }
                Text(text)
                    .font(.callout)
                    .foregroundStyle(isPartial ? .secondary : .primary)
                    .italic(isPartial)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if !alignRight { Spacer(minLength: 40) }
        }
    }
}
