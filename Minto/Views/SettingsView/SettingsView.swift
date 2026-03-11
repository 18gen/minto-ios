import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Defaults") {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }

                Picker("Default Tone", selection: $settings.defaultToneMode) {
                    Text("Casual (\u{30BF}\u{30E1}\u{53E3})").tag("casual")
                    Text("Business (\u{3067}\u{3059}/\u{307E}\u{3059})").tag("business")
                    Text("Formal (\u{656C}\u{8A9E})").tag("formal")
                }

                Toggle("Auto-record when meeting starts", isOn: $settings.autoRecord)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
