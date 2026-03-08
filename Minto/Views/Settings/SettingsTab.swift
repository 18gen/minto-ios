import SwiftData
import SwiftUI

struct SettingsTab: View {
    @State private var settings = AppSettings.shared
    @Query private var speakerProfiles: [SpeakerProfile]

    private var hasPicovoiceKey: Bool { !AppSettings.picovoiceKey.isEmpty }

    var body: some View {
        Form {
            Section("Defaults") {
                Picker("Default Tone", selection: $settings.defaultToneMode) {
                    Text("Casual (\u{30BF}\u{30E1}\u{53E3})").tag("casual")
                    Text("Business (\u{3067}\u{3059}/\u{307E}\u{3059})").tag("business")
                    Text("Formal (\u{656C}\u{8A9E})").tag("formal")
                }

                Toggle("Auto-record when meeting starts", isOn: $settings.autoRecord)
            }

            Section {
                if hasPicovoiceKey {
                    NavigationLink {
                        VoiceEnrollmentView()
                    } label: {
                        HStack {
                            Label("Voice ID", systemImage: "person.wave.2")
                            Spacer()
                            if let profile = speakerProfiles.first, profile.isComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    HStack {
                        Label("Voice ID", systemImage: "person.wave.2")
                        Spacer()
                        Text("Key Required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Speaker Recognition")
            } footer: {
                if !hasPicovoiceKey {
                    Text("Add PICOVOICE_ACCESS_KEY to enable automatic speaker identification.")
                } else if speakerProfiles.first?.isComplete == true {
                    Text("Your voice is enrolled. Minto will auto-label your speech in transcripts.")
                } else {
                    Text("Enroll your voice so Minto can identify you in transcripts.")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
