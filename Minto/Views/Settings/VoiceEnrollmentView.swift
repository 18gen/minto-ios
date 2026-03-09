import SwiftData
import SwiftUI

struct VoiceEnrollmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SpeakerProfile]

    @State private var vm = VoiceEnrollmentViewModel()

    private var existingProfile: SpeakerProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 24) {
            statusIcon
            titleSection
            progressSection
            errorSection
            Spacer()
            actionButtons
        }
        .navigationTitle("Voice ID")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { vm.cleanup() }
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(vm.isEnrolling ? AppTheme.accent.opacity(0.15) : Color.secondary.opacity(0.08))
                .frame(width: 100 + CGFloat(vm.audioLevel) * 40, height: 100 + CGFloat(vm.audioLevel) * 40)
                .animation(.easeOut(duration: 0.1), value: vm.audioLevel)

            Circle()
                .fill(vm.isEnrolling ? AppTheme.accent.opacity(0.25) : Color.secondary.opacity(0.12))
                .frame(width: 80, height: 80)

            Image(systemName: existingProfile?.isComplete == true ? "checkmark.circle.fill" : "waveform")
                .font(.system(size: 32))
                .foregroundStyle(existingProfile?.isComplete == true ? .green : vm.isEnrolling ? AppTheme.accent : .secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            if existingProfile?.isComplete == true && !vm.isEnrolling {
                Text("Voice Enrolled")
                    .font(.title3.weight(.semibold))
                Text("Your voice profile is set up. Minto will automatically identify you during recordings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if vm.isEnrolling {
                Text("Keep Speaking...")
                    .font(.title3.weight(.semibold))
                Text(vm.feedbackText)
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
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        if vm.isEnrolling || (existingProfile?.isComplete == true) {
            VStack(spacing: 6) {
                ProgressView(value: Double(vm.percentage), total: 100)
                    .tint(AppTheme.accent)
                Text("\(Int(vm.percentage))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = vm.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if vm.isEnrolling {
                if vm.percentage >= 100 {
                    Button {
                        vm.finishEnrollment(existingProfile: existingProfile, modelContext: modelContext)
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
                    vm.cancelEnrollment(existingProfile: existingProfile)
                }
                .foregroundStyle(.secondary)
            } else {
                Button {
                    vm.startEnrollment()
                } label: {
                    Text(existingProfile?.isComplete == true ? "Re-enroll Voice" : "Start Enrollment")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if let profile = existingProfile, profile.isComplete {
                    Button(role: .destructive) {
                        vm.deleteProfile(profile, modelContext: modelContext)
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
}
