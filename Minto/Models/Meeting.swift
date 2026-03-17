import Foundation
import SwiftData

@Model
final class Meeting {
    var title: String
    var startDate: Date
    var endDate: Date?

    var userNotes: String
    var rawTranscript: String
    var augmentedNotes: String
    var blocksJSON: String = ""
    var augmentedBlocksJSON: String = ""

    var status: String

    /// JSON-encoded [String: String] mapping speaker index → display name.
    var speakerNamesData: Data?

    /// The speaker index the user has marked as "me", or nil if unset.
    var userSpeakerIndex: Int?

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.meeting)
    var segments: [TranscriptSegment]

    init(
        title: String = "New Meeting",
        startDate: Date = .now
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = nil
        self.userNotes = ""
        self.rawTranscript = ""
        self.augmentedNotes = ""
        self.blocksJSON = ""
        self.status = "idle"
        self.speakerNamesData = nil
        self.userSpeakerIndex = nil
        self.segments = []
    }

    // MARK: - Block Helpers

    var blocks: [Block] {
        get {
            guard !blocksJSON.isEmpty,
                  let data = blocksJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Block].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            blocksJSON = String(data: data, encoding: .utf8) ?? ""
        }
    }

    var augmentedBlocks: [Block] {
        get {
            guard !augmentedBlocksJSON.isEmpty,
                  let data = augmentedBlocksJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Block].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            augmentedBlocksJSON = String(data: data, encoding: .utf8) ?? ""
        }
    }

    // MARK: - Speaker Name Helpers

    var speakerNames: [Int: String] {
        get {
            guard let data = speakerNamesData,
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            var result: [Int: String] = [:]
            for (key, value) in dict {
                if let intKey = Int(key) { result[intKey] = value }
            }
            return result
        }
        set {
            let stringKeyDict = Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) })
            speakerNamesData = try? JSONEncoder().encode(stringKeyDict)
        }
    }

    func markSpeakerAsUser(_ speakerIndex: Int) {
        // Clear previous designation
        if let prev = userSpeakerIndex {
            for segment in segments where segment.speaker == prev {
                segment.isUserSpeaker = false
                segment.speakerLabel = nil
            }
        }

        userSpeakerIndex = speakerIndex

        // Set new designation
        for segment in segments where segment.speaker == speakerIndex {
            segment.isUserSpeaker = true
            segment.speakerLabel = L("speaker.you")
        }
    }

    func renameSpeaker(_ speakerIndex: Int, to name: String) {
        var names = speakerNames
        names[speakerIndex] = name
        speakerNames = names

        for segment in segments where segment.speaker == speakerIndex {
            segment.speakerLabel = name.isEmpty ? nil : name
        }
    }
}
