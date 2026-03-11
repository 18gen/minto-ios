import SwiftUI

struct TranscriptPanelView: View {
    @Bindable var meeting: Meeting

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                Button {
                    UIPasteboard.general.string = meeting.rawTranscript
                    Haptic.notification(.success)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            TranscriptContent(meeting: meeting)
        }
    }
}
