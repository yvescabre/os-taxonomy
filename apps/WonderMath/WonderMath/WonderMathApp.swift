import SwiftUI
import SwiftData
import WonderMathCore

@main
struct WonderMathApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChildProfile.self,
            MasteryRecord.self,
            Achievement.self,
            DailyAdventureLog.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task { appState.load() }
        }
        .modelContainer(sharedModelContainer)
    }
}
