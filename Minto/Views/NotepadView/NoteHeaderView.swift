import SwiftUI

struct NoteHeaderView: View {
    @Bindable var meeting: Meeting
    @Bindable var enhancer: NoteEnhancer

    @State private var pendingTemplate: NoteTemplate?
    @State private var showReenhanceAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("New Note", text: $meeting.title)
                    .textFieldStyle(.plain)
                    .font(.system(.title, design: .serif))
                    .foregroundStyle(.primary)

                NoteToggle(
                    showingEnhanced: $enhancer.showingEnhanced,
                    isLoading: enhancer.isAugmenting,
                    hasTranscript: !meeting.rawTranscript.isEmpty,
                    onTapEnhance: { enhancer.tapEnhance(meeting: meeting) },
                    onSelectTemplate: { template in
                        if meeting.augmentedNotes.isEmpty {
                            enhancer.enhance(meeting: meeting, template: template)
                        } else {
                            pendingTemplate = template
                            showReenhanceAlert = true
                        }
                    }
                )
            }

            if let error = enhancer.augmentError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .alert("Re-enhance notes?", isPresented: $showReenhanceAlert) {
            Button("Cancel", role: .cancel) { pendingTemplate = nil }
            Button("Re-enhance", role: .destructive) {
                if let template = pendingTemplate {
                    enhancer.enhance(meeting: meeting, template: template)
                    pendingTemplate = nil
                }
            }
        } message: {
            Text("Your current enhanced notes will be replaced.")
        }
    }
}
