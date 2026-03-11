import SwiftUI

struct NoteToggle: View {
    @Binding var showingEnhanced: Bool
    let isLoading: Bool
    let hasTranscript: Bool
    let onTapEnhance: () -> Void
    let onSelectTemplate: (NoteTemplate) -> Void

    var body: some View {
        if hasTranscript {
            HStack(spacing: 0) {
                // Notes side
                Button {
                    Haptic.impact(.light)
                    showingEnhanced = false
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(!showingEnhanced ? Color.white.opacity(0.12) : .clear)
                        )
                }
                .buttonStyle(.plain)

                // AI side — Button when on notes, Menu when on enhanced
                if showingEnhanced {
                    Menu {
                        ForEach(NoteTemplate.allCases) { template in
                            Button {
                                onSelectTemplate(template)
                            } label: {
                                Label(template.label, systemImage: template.icon)
                            }
                        }
                    } label: {
                        aiLabel
                    }
                } else {
                    Button {
                        Haptic.impact(.light)
                        onTapEnhance()
                    } label: {
                        aiLabel
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.surfaceStroke, lineWidth: 1)
            )
        }
    }

    private var aiLabel: some View {
        HStack(spacing: 3) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 50, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(showingEnhanced ? Color.white.opacity(0.12) : .clear)
        )
    }
}
