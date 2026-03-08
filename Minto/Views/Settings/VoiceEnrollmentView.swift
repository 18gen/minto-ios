import SwiftData
import SwiftUI

struct VoiceEnrollmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SpeakerProfile]

    @State private var enrollmentService = VoiceEnrollmentService()
    @State private var percentage: Float = 0
    @State private var feedback: String = ""
    @State private var isEnrolling = false
    @State private var errorMessage: String?
    @State private var audioLevel: Float = 0
    @State private var pollTimer: Timer?

    private var existingProfile: SpeakerProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 24) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isEnrolling ? AppTheme.accent.opacity(0.15) : Color.secondary.opacity(0.08))
                    .frame(width: 100 + CGFloat(audioLevel) * 40, height: 100 + CGFloat(audioLevel) * 40)
                    .animation(.easeOut(duration: 0.1), value: audioLevel)

                Circle()
                    .fill(isEnrolling ? AppTheme.accent.opacity(0.25) : Color.secondary.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: existingProfile?.isComplete == true ? "checkmark.circle.fill" : "waveform")
                    .font(.system(size: 32))
                    .foregroundStyle(existingProfile?.isComplete == true ? .green : isEnrolling ? AppTheme.accent : .secondary)
            }
            .padding(.top, 20)

            // Title and description
            VStack(spacing: 8) {
                if existingProfile?.isComplete == true && !isEnrolling {
                    Text("Voice Enrolled")
                        .font(.title3.weight(.semibold))
                    Text("Your voice profile is set up. Minto will automatically identify you during recordings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if isEnrolling {
                    Text("Keep Speaking...")
                        .font(.title3.weight(.semibold))
                    Text(feedbackText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Set Up My Voice")
                        .font(.title3.weight(.semibold))
                    Text("Speak naturally for about 30 seconds so Minto can learn your voice and automatically label your speech in transcripts.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            // Progress bar
            if isEnrolling || (existingProfile?.isComplete == true) {
                VStack(spacing: 6) {
                    ProgressView(value: Double(percentage), total: 100)
                        .tint(AppTheme.accent)

                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                if isEnrolling {
                    if percentage >= 100 {
                        Button {
                            finishEnrollment()
                        } label: {
                            Text("Save Voice Profile")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    Button("Cancel") {
                        cancelEnrollment()
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        startEnrollment()
                    } label: {
                        Text(existingProfile?.isComplete == true ? "Re-enroll Voice" : "Start Enrollment")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if existingProfile?.isComplete == true {
                        Button(role: .destructive) {
                            deleteProfile()
                        } label: {
                            Text("Remove Voice Profile")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Voice ID")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            pollTimer?.invalidate()
            enrollmentService.cleanup()
        }
    }

    private var feedbackText: String {
        if percentage >= 100 { return "Enrollment complete! Tap Save to finish." }
        return feedback.isEmpty ? "Speak naturally — read aloud, describe your day, or just talk." : feedback
    }

    private func startEnrollment() {
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

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            Task { @MainActor in
                percentage = enrollmentService.enrollmentPercentage
                audioLevel = enrollmentService.audioLevel

                feedback = enrollmentService.feedbackMessage
            }
        }
    }

    private func finishEnrollment() {
        pollTimer?.invalidate()
        do {
            let profileData = try enrollmentService.exportProfile()
            enrollmentService.stopEnrollment()
            isEnrolling = false

            // Save or update the profile
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

    private func cancelEnrollment() {
        pollTimer?.invalidate()
        enrollmentService.stopEnrollment()
        isEnrolling = false
        percentage = Float(existingProfile?.enrollmentPercentage ?? 0)
    }

    private func deleteProfile() {
        if let existing = existingProfile {
            modelContext.delete(existing)
            percentage = 0
        }
    }
}
