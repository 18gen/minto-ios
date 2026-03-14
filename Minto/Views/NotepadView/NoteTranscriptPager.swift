import SwiftData
import SwiftUI

enum NotePage: Int, CaseIterable {
    case notes = 0
    case transcript = 1
}

struct NoteTranscriptPager<NotesContent: View>: View {
    @Binding var currentPage: NotePage
    @Bindable var meeting: Meeting
    var onClearFocus: (() -> Void)?
    @ViewBuilder var notesContent: () -> NotesContent

    private let coordinator = iOSRecordingCoordinator.shared

    private var hasTranscript: Bool {
        !meeting.segments.isEmpty || !meeting.rawTranscript.isEmpty || !coordinator.currentPartial.isEmpty
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            TabView(selection: $currentPage) {
                notesContent()
                    .tag(NotePage.notes)
                    .background(ScrollViewDelayFix())

                TranscriptPanelView(meeting: meeting)
                    .tag(NotePage.transcript)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { _, newPage in
                if newPage == .transcript {
                    onClearFocus?()
                }
            }

            if currentPage == .notes, hasTranscript {
                edgeIndicator
            }
        }
    }

    private var edgeIndicator: some View {
        Button {
            withAnimation(AppTheme.Anim.spring) {
                currentPage = .transcript
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "text.quote")
                    .font(.system(size: 12))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.surface.opacity(0.8))
            )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 2)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}
