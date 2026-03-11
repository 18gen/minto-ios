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

                Toggle(L("settings.autoRecord"), isOn: $settings.autoRecord)
            }
        }
        .navigationTitle(L("nav.settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
