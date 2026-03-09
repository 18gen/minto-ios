import SwiftUI

@Observable @MainActor
final class HomeViewModel {
    var askText = ""
    var isAsking = false

    func onAppear() async {}

    static func recentContext(from meetings: [Meeting], limit: Int = 5) -> String {
        meetings.prefix(limit).map {
            "Meeting: \($0.title)\nNotes: \($0.userNotes)\nTranscript: \($0.rawTranscript)"
        }
        .joined(separator: "\n---\n")
    }
}
