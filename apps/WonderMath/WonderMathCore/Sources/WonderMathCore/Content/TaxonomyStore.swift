import Foundation

/// Loads the curated taxonomy subset bundled with the app, indexes topics by
/// id and builds the prerequisite graph. Pure Foundation: the same code path
/// is exercised by Linux unit tests and the app.
public final class TaxonomyStore: @unchecked Sendable {

    public enum LoaderError: Error, Equatable {
        case missingFile(String)
        case decodeFailed(String)
    }

    public private(set) var topics: [Topic] = []
    public private(set) var dependencies: [Dependency] = []
    public private(set) var records: [String: TeachingRecord] = [:]
    public private(set) var coverage: TeachingCoverage?

    public private(set) var topicsById: [String: Topic] = [:]
    public private(set) var graph = SkillGraph()

    public init() {}

    // MARK: Loading

    /// Load the three taxonomy files from a directory (Linux tests, scripts).
    public func load(directory: URL) throws {
        try load(
            topics: data("topics.json", in: directory),
            dependencies: data("dependencies.json", in: directory),
            research: data("teaching-research.json", in: directory)
        )
    }

    /// Load from the app bundle. Tolerates both a `Taxonomy/` folder reference
    /// and flattened bundle resources.
    public func load(bundle: Bundle = .main) throws {
        func resource(_ name: String) throws -> Data {
            let stem = (name as NSString).deletingPathExtension
            if let url = bundle.url(forResource: stem, withExtension: "json", subdirectory: "Taxonomy")
                ?? bundle.url(forResource: stem, withExtension: "json") {
                return try Data(contentsOf: url)
            }
            throw LoaderError.missingFile(name)
        }
        try load(
            topics: resource("topics.json"),
            dependencies: resource("dependencies.json"),
            research: resource("teaching-research.json")
        )
    }

    /// Load from in-memory data (also used for hand-built fixtures in tests).
    public func load(topics topicsData: Data, dependencies depsData: Data, research researchData: Data) throws {
        let decoder = JSONDecoder()
        do {
            let tf = try decoder.decode(TopicsFile.self, from: topicsData)
            topics = tf.topics
        } catch { throw LoaderError.decodeFailed("topics.json: \(error)") }
        do {
            let df = try decoder.decode(DependenciesFile.self, from: depsData)
            dependencies = df.dependencies
        } catch { throw LoaderError.decodeFailed("dependencies.json: \(error)") }
        do {
            let rf = try decoder.decode(TeachingResearchFile.self, from: researchData)
            records = Dictionary(uniqueKeysWithValues: rf.records.map { ($0.topicId, $0) })
            coverage = rf.coverage
        } catch { throw LoaderError.decodeFailed("teaching-research.json: \(error)") }

        topicsById = Dictionary(uniqueKeysWithValues: topics.map { ($0.id, $0) })
        graph = SkillGraph(dependencies: dependencies, knownIds: Set(topicsById.keys))
    }

    private func data(_ name: String, in directory: URL) throws -> Data {
        let url = directory.appendingPathComponent(name)
        guard let d = try? Data(contentsOf: url) else { throw LoaderError.missingFile(name) }
        return d
    }

    // MARK: Lookups

    public func topic(_ id: String) -> Topic? { topicsById[id] }

    /// Teaching research for a topic, or nil. ~80 bundled Mathematics topics
    /// and all Computing topics have no research — callers must degrade
    /// gracefully (see `TeachingGuide`).
    public func research(for topicId: String) -> TeachingRecord? { records[topicId] }

    public func topics(inSubject subject: String, domain: String? = nil) -> [Topic] {
        topics.filter { $0.subject == subject && (domain == nil || $0.domain == domain) }
    }
}
