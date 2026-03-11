import SwiftUI

struct TranscriptSheetView: View {
    @Bindable var meeting: Meeting
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TranscriptContent(meeting: meeting)
                .navigationTitle(L("nav.transcript"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            UIPasteboard.general.string = meeting.rawTranscript
                            Haptic.notification(.success)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L("button.done")) { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
