import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section(L("section.defaults")) {
                Picker(L("settings.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }

                Picker(L("settings.defaultTone"), selection: $settings.defaultToneMode) {
                    Text(L("settings.toneCasual")).tag("casual")
                    Text(L("settings.toneBusiness")).tag("business")
                    Text(L("settings.toneFormal")).tag("formal")
                }

                Toggle(L("settings.autoRecord"), isOn: $settings.autoRecord)
            }
        }
        .navigationTitle(L("nav.settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
