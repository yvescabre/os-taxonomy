import Foundation
@testable import WonderMathCore

enum TestSupport {
    /// The bundled taxonomy subset inside the app target.
    static var taxonomyDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WonderMathCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // WonderMathCore
            .deletingLastPathComponent()   // WonderMath app root
            .appendingPathComponent("WonderMath/Resources/Taxonomy")
    }

    static func loadStore() throws -> TaxonomyStore {
        let store = TaxonomyStore()
        try store.load(directory: taxonomyDirectory)
        return store
    }

    static let registry = GeneratorRegistry.makeDefault()
    static let engine = AdaptiveEngine()
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Topological order of every playable (generator-backed) topic.
    static func playableOrder(_ store: TaxonomyStore) -> [String] {
        store.graph.topologicalOrder(of: registry.playableTopicIds) { store.topic($0) }
    }
}
