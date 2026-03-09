import SwiftData
import SwiftUI

@Observable @MainActor
final class VoiceEnrollmentViewModel {
    var percentage: Float = 0
    var feedback: String = ""
    var isEnrolling = false
    var errorMessage: String?
    var audioLevel: Float = 0

    private var enrollmentService = VoiceEnrollmentService()
    private var pollTimer: Timer?

    var feedbackText: String {
        if percentage >= 100 { return "Enrollment complete! Tap Save to finish." }
        return feedback.isEmpty ? "Speak naturally — read aloud, describe your day, or just talk." : feedback
    }

    func startEnrollment() {
        errorMessage = nil
        do {
            try enrollmentService.initialize()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        Task {
            do {
                try await enrollmentService.startEnrollment()
                isEnrolling = true
                startPolling()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func finishEnrollment(existingProfile: SpeakerProfile?, modelContext: ModelContext) {
        pollTimer?.invalidate()
        do {
            let profileData = try enrollmentService.exportProfile()
            enrollmentService.stopEnrollment()
            isEnrolling = false

            if let existing = existingProfile {
                existing.profileData = profileData
                existing.enrollmentPercentage = Double(percentage)
                existing.createdAt = .now
            } else {
                let profile = SpeakerProfile(
                    name: "My Voice",
                    profileData: profileData,
                    createdAt: .now,
                    enrollmentPercentage: Double(percentage)
                )
                modelContext.insert(profile)
            }
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
    }

    func cancelEnrollment(existingProfile: SpeakerProfile?) {
        pollTimer?.invalidate()
        enrollmentService.stopEnrollment()
        isEnrolling = false
        percentage = Float(existingProfile?.enrollmentPercentage ?? 0)
    }

    func deleteProfile(_ profile: SpeakerProfile, modelContext: ModelContext) {
        modelContext.delete(profile)
        percentage = 0
    }

    func cleanup() {
        pollTimer?.invalidate()
        enrollmentService.cleanup()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.percentage = self.enrollmentService.enrollmentPercentage
                self.audioLevel = self.enrollmentService.audioLevel
                self.feedback = self.enrollmentService.feedbackMessage
            }
        }
    }
}
