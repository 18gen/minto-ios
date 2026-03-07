import SwiftUI
import SwiftData
import UIKit

enum NotePage: Int, CaseIterable {
    case notes = 0
    case transcript = 1
}

struct NoteTranscriptPager<NotesContent: View>: View {
    @Binding var currentPage: NotePage
    @Bindable var meeting: Meeting
    @ViewBuilder var notesContent: () -> NotesContent

    @State private var coordinator = iOSRecordingCoordinator.shared

    private var hasTranscript: Bool {
        !meeting.segments.isEmpty || !meeting.rawTranscript.isEmpty || !coordinator.currentPartial.isEmpty
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            TabView(selection: $currentPage) {
                notesContent()
                    .tag(NotePage.notes)

                TranscriptPanelView(meeting: meeting, isInline: true)
                    .tag(NotePage.transcript)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { _, newPage in
                if newPage == .transcript {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }

            if currentPage == .notes && hasTranscript {
                edgeIndicator
            }
        }
    }

    private var edgeIndicator: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                    .fill(AppTheme.surfaceFill.opacity(0.8))
            )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 2)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}
