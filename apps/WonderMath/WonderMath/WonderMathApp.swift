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
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITestInMemory")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
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
                .preferredColorScheme(.light)
                .task { appState.load() }
        }
        .modelContainer(sharedModelContainer)
    }
}
