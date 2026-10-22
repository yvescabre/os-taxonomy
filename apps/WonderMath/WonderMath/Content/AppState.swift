import Foundation
import Combine
import WonderMathCore

@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published var language: AppLanguage = .english

    let registry = GeneratorRegistry.makeDefault()
    private(set) var store = TaxonomyStore()

    var localizer: Localizer { Localizer(language: language) }
    var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-UITestInMemory") }

    var playableOrder: [String] {
        let worldTopics = Set(WorldCatalog.topicIds(for: .numberKingdom, in: store))
        let playable = registry.playableTopicIds.filter { worldTopics.contains($0) }
        return store.graph.topologicalOrder(of: playable) { store.topic($0) }
    }

    func load() {
        phase = .loading
        Task {
            let loadedStore = TaxonomyStore()
            do {
                try await Task.detached(priority: .userInitiated) {
                    try loadedStore.load(bundle: .main)
                }.value
                store = loadedStore
                phase = .ready
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
