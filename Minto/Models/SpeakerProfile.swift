import Foundation
import SwiftData

@Model
final class SpeakerProfile {
    var name: String
    var profileData: Data
    var createdAt: Date
    var enrollmentPercentage: Double

    init(
        name: String = "My Voice",
        profileData: Data = Data(),
        createdAt: Date = .now,
        enrollmentPercentage: Double = 0
    ) {
        self.name = name
        self.profileData = profileData
        self.createdAt = createdAt
        self.enrollmentPercentage = enrollmentPercentage
    }

    var isComplete: Bool { enrollmentPercentage >= 100.0 }
}
