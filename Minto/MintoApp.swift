import SwiftData
import SwiftUI

@main
struct MintoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meeting.self,
            TranscriptSegment.self,
            ChatConversation.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await AppSettings.fetchKeys() }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            let coordinator = iOSRecordingCoordinator.shared
            switch newPhase {
            case .background:
                coordinator.handleAppBackgrounded()
            case .active:
                coordinator.handleAppForegrounded()
            default:
                break
            }
        }
    }
}
