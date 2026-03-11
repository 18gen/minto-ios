import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = AppSettings.shared
    @State private var showDeleteAlert = false

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

            Section(L("section.dangerZone")) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text(L("settings.deleteAllData"))
                }
            }
        }
        .navigationTitle(L("nav.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("alert.deleteAllTitle"), isPresented: $showDeleteAlert) {
            Button(L("button.cancel"), role: .cancel) {}
            Button(L("button.delete"), role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text(L("alert.deleteAllMessage"))
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Meeting.self)
            try modelContext.delete(model: ChatConversation.self)
            try modelContext.save()
            Haptic.notification(.success)
        } catch {
            print("Failed to delete all data: \(error)")
        }
    }
}
